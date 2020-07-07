// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"context"
	"fmt"
	"io/ioutil"
	"math/rand"
	"os"
	"path"
	"sort"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/Avere/src/go/pkg/stats"
	"github.com/Azure/azure-sdk-for-go/profiles/latest/compute/mgmt/compute"
)

// WarmPathManager contains the information for the manager
type WarmPathManager struct {
	AzureClients          *AzureClients
	JobSubmitterPath      string
	JobWorkerPath         string
	bootstrapMountAddress string
	bootstrapExportPath   string
	bootstrapScriptPath   string
	jobMountAddress       string
	jobExportPath         string
	jobBasePath           string
	vmssUserName          string
	vmssPassword          string
	vmssSshPublicKey      string
	vmssSubnet            string
}

// InitializeWarmPathManager initializes the job submitter structure
func InitializeWarmPathManager(
	azureClients *AzureClients,
	jobSubmitterPath string,
	jobWorkerPath string,
	bootstrapMountAddress string,
	bootstrapExportPath string,
	bootstrapScriptPath string,
	jobMountAddress string,
	jobExportPath string,
	jobBasePath string,
	vmssUserName string,
	vmssPassword string,
	vmssSshPublicKey string,
	vmssSubnet string) *WarmPathManager {
	return &WarmPathManager{
		AzureClients:          azureClients,
		JobSubmitterPath:      jobSubmitterPath,
		JobWorkerPath:         jobWorkerPath,
		bootstrapMountAddress: bootstrapMountAddress,
		bootstrapExportPath:   bootstrapExportPath,
		bootstrapScriptPath:   bootstrapScriptPath,
		jobMountAddress:       jobMountAddress,
		jobExportPath:         jobExportPath,
		jobBasePath:           jobBasePath,
		vmssUserName:          vmssUserName,
		vmssPassword:          vmssPassword,
		vmssSshPublicKey:      vmssSshPublicKey,
		vmssSubnet:            vmssSubnet,
	}
}

func (m *WarmPathManager) RunJobGenerator(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	log.Debug.Printf("[WarmPathManager.RunJobGenerator")
	defer log.Debug.Printf("WarmPathManager.RunJobGenerator]")
	defer syncWaitGroup.Done()

	lastJobCheckTime := time.Now().Add(-timeBetweenJobCheck)
	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	// initialize random generator
	rand.Seed(time.Now().Unix())

	// run the infinite loop
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if time.Since(lastJobCheckTime) > timeBetweenJobCheck {
				lastJobCheckTime = time.Now()
				log.Info.Printf("check jobs in path %s", m.JobSubmitterPath)

				files, err := ioutil.ReadDir(m.JobSubmitterPath)
				if err != nil {
					log.Error.Printf("error reading path %s: %v", m.JobSubmitterPath, err)
					continue
				}

				for _, file := range files {
					filename := path.Join(m.JobSubmitterPath, file.Name())
					if err := m.processJobFile(ctx, filename); err != nil {
						log.Error.Printf("error encountered processing file %s: %v", file.Name(), err)
					}
					if isCancelled(ctx) {
						log.Info.Printf("cancelation occurred while processing job files")
						return
					}
				}
			}
		}
	}
}

func (m *WarmPathManager) processJobFile(ctx context.Context, filename string) error {
	log.Debug.Printf("[WarmPathManager.processJobFile %s", filename)
	defer log.Debug.Printf("WarmPathManager.processJobFile %s]", filename)

	byteContent, err := ioutil.ReadFile(filename)
	if err != nil {
		return fmt.Errorf("error processing job file: %v", err)
	}

	warmPathJob, err := InitializeWarmPathJobFromString(string(byteContent))
	if err != nil {
		if err2 := os.Remove(filename); err != nil {
			log.Error.Printf("error removing file %s: %v", filename, err2)
		}
		return fmt.Errorf("error parsing file into warmPathJob, file %s removed: %v", filename, err)
	}

	if len(warmPathJob.WarmTargetMountAddresses) == 0 {
		if err2 := os.Remove(filename); err != nil {
			log.Error.Printf("error removing file %s: %v", filename, err2)
		}
		return fmt.Errorf("there are no mount addresses specified in the file")
	}

	localMountPath := GetLocalMountPath(warmPathJob.WarmTargetMountAddresses[0], warmPathJob.WarmTargetExportPath)
	if err := MountPath(warmPathJob.WarmTargetMountAddresses[0], warmPathJob.WarmTargetExportPath, localMountPath); err != nil {
		return fmt.Errorf("error trying to mount %s:%s: %v", warmPathJob.WarmTargetMountAddresses[0], warmPathJob.WarmTargetExportPath, err)
	}

	log.Status.Printf("start processing %s", warmPathJob.WarmTargetPath)
	defer log.Status.Printf("stop processing %s", warmPathJob.WarmTargetPath)

	folderSlice := []string{warmPathJob.WarmTargetPath}
	for len(folderSlice) > 0 {
		// check for cancelation between files
		if isCancelled(ctx) {
			log.Info.Printf("cancelation occurred while processing job files")
			return nil
		}
		warmFolder := folderSlice[len(folderSlice)-1]
		folderSlice[len(folderSlice)-1] = ""
		folderSlice = folderSlice[:len(folderSlice)-1]

		// queue up additional folders
		fullWarmPath := path.Join(localMountPath, warmFolder)
		dirEntries, err := ioutil.ReadDir(fullWarmPath)
		if err != nil {
			log.Error.Printf("error encountered reading directory '%s': %v", warmFolder, err)
			continue
		}

		files, largeFiles, dirs := processDirEntries(dirEntries)

		// queue the directories
		for _, dir := range dirs {
			if !isCacheWarmerFolder(dir.Name()) {
				folderSlice = append(folderSlice, path.Join(warmFolder, dir.Name()))
			}
		}

		// write a job for each large file
		for _, largeFile := range largeFiles {
			fullPath := path.Join(warmFolder, largeFile.Name())

			fileSize := largeFile.Size()
			for i := int64(0); i < fileSize; i += MaximumJobSize {
				end := i + MaximumJobSize
				if end > fileSize {
					end = fileSize
				}
				log.Info.Printf("queuing job for file %s [%d,%d)", fullPath, i, end)
				workerJob := InitializeWorkerJobForLargeFile(warmPathJob.WarmTargetMountAddresses, warmPathJob.WarmTargetExportPath, fullPath, i, end)
				go writeJob(workerJob, m.JobWorkerPath)
			}
		}

		// write a job for each group of files
		if len(files) > 0 {
			if len(files) < MaximumFilesToRead {
				log.Info.Printf("queuing job for path %s", warmFolder)
				workerJob := InitializeWorkerJob(warmPathJob.WarmTargetMountAddresses, warmPathJob.WarmTargetExportPath, warmFolder)
				go writeJob(workerJob, m.JobWorkerPath)
			} else {
				for i := 0; i < len(files); i += MaximumFilesToRead {
					end := i + MaximumFilesToRead
					if end >= len(files) {
						end = len(files) - 1
					}
					log.Info.Printf("queuing job for path %s [%s,%s]", warmFolder, files[i].Name(), files[end].Name())
					workerJob := InitializeWorkerJobWithFilter(warmPathJob.WarmTargetMountAddresses, warmPathJob.WarmTargetExportPath, warmFolder, files[i].Name(), files[end].Name())
					go writeJob(workerJob, m.JobWorkerPath)
				}
			}
		}
	}

	// remove the job file
	if err := os.Remove(filename); err != nil {
		return fmt.Errorf("error removing file %v", err)
	}

	return nil
}

func processDirEntries(dirEntries []os.FileInfo) ([]os.FileInfo, []os.FileInfo, []os.FileInfo) {
	// bucketize the files into files, largeFiles, and dirs
	fileSizes := make([]int64, 0, len(dirEntries))
	files := make([]os.FileInfo, 0, len(dirEntries))
	largeFiles := make([]os.FileInfo, 0, len(dirEntries))
	dirs := make([]os.FileInfo, 0, len(dirEntries))

	for _, dirEntry := range dirEntries {
		if dirEntry.IsDir() {
			dirs = append(dirs, dirEntry)
		} else { /* !dirEntry.IsDir() */
			fileSizes = append(fileSizes, dirEntry.Size())
			if dirEntry.Size() >= MinimumSingleFileSize {
				largeFiles = append(largeFiles, dirEntry)
			} else {
				files = append(files, dirEntry)
			}
		}
	}

	printStats(fileSizes, len(dirs))

	return files, largeFiles, dirs
}

func printStats(fileSizes []int64, dirCount int) {
	if len(fileSizes) == 0 {
		log.Status.Printf("dir stats: dircount, filecount, totalfilesize, P0, P10, P50, P75, P90, P95, P99, P100: %d, 0, 0, -1, -1, -1, -1, -1, -1, -1, -1",
			dirCount)
		return
	}
	totalSize := int64(0)
	for _, size := range fileSizes {
		totalSize += size
	}
	sort.Slice(fileSizes, func(x, y int) bool { return fileSizes[x] < fileSizes[y] })
	// get the statistics, directory count, file count, total filesize, P0, P10, P50, P75, P90, P95, P99, P100
	log.Status.Printf("dir stats: dircount, filecount, totalfilesize, P0, P10, P50, P75, P90, P95, P99, P100: %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d",
		dirCount,
		len(fileSizes),
		totalSize,
		fileSizes[0],
		fileSizes[stats.GetPercentileIndex(float64(10), len(fileSizes))],
		fileSizes[stats.GetPercentileIndex(float64(50), len(fileSizes))],
		fileSizes[stats.GetPercentileIndex(float64(75), len(fileSizes))],
		fileSizes[stats.GetPercentileIndex(float64(90), len(fileSizes))],
		fileSizes[stats.GetPercentileIndex(float64(95), len(fileSizes))],
		fileSizes[stats.GetPercentileIndex(float64(99), len(fileSizes))],
		fileSizes[len(fileSizes)-1])
}

func writeJob(workerJob *WorkerJob, jobPath string) {
	if err := workerJob.WriteJob(jobPath); err != nil {
		log.Error.Printf("error writing worker job to %s: %v", jobPath, err)
	}
}

func isCacheWarmerFolder(folder string) bool {
	return folder == DefaultCacheJobSubmitterDir || folder == DefaultCacheWorkerJobsDir
}

func (m *WarmPathManager) RunVMSSManager(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	log.Debug.Printf("[WarmPathManager.RunVMSSManager")
	defer log.Debug.Printf("WarmPathManager.RunVMSSManager]")
	defer syncWaitGroup.Done()

	lastWorkerJobCheckTime := time.Now().Add(-timeBetweenWorkerJobCheck)
	lastReadDirSuccess := time.Now()
	lastJobSeen := time.Now()
	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	// run the infinite loop
	for {
		select {
		case <-ctx.Done():
			log.Info.Printf("cancelation received")
			return
		case <-ticker.C:
			if time.Since(lastWorkerJobCheckTime) > timeBetweenWorkerJobCheck {
				lastWorkerJobCheckTime = time.Now()
				log.Info.Printf("check jobs in path %s", m.JobWorkerPath)
				jobsExist, mountCount, err := JobsExist(m.JobWorkerPath)
				if err != nil {
					log.Error.Printf("error reading path %s: %v, ", m.JobWorkerPath, err)
					if time.Since(lastReadDirSuccess) > failureTimeToDeleteVMSS {
						log.Error.Printf("read directory has not been successful for 15 minutes, ensure vmss deleted")
						m.EnsureVmssDeleted(ctx)
						// reset the last read dir success
						lastReadDirSuccess = time.Now()
					}
					continue
				}
				log.Info.Printf("jobsExist %v", jobsExist)
				lastReadDirSuccess = time.Now()

				if jobsExist {
					m.EnsureVmssRunning(ctx, mountCount)
					lastJobSeen = time.Now()
				} else {
					if time.Since(lastJobSeen) > timeToDeleteVMSSAfterNoJobs {
						m.EnsureVmssDeleted(ctx)
					}
				}
			}
		}
	}
}

func (m *WarmPathManager) EnsureVmssRunning(ctx context.Context, mountCount int) {
	vmssExists, err := VmssExists(ctx, m.AzureClients, VmssName)
	if err != nil {
		log.Error.Printf("checking VMSS existence failed with error %v", err)
		return
	}
	if vmssExists {
		log.Debug.Printf("vmss is already running")
		return
	}
	// get the controller subnet id
	localVMSubnetId, err := GetSubnetId(ctx, m.AzureClients)
	if err != nil {
		log.Error.Printf("ERROR: failed to initialize Azure Clients: %s", err)
		return
	}
	vmssSubnetId := localVMSubnetId
	if len(m.vmssSubnet) > 0 {
		// swap the subnet if the customer requested an alternative subnet
		vmssSubnetId = SwapResourceName(localVMSubnetId, m.vmssSubnet)
	}

	cacheWarmerCloudInit := InitializeCloutInit(
		m.bootstrapMountAddress, // bootstrapAddress string,
		m.bootstrapExportPath,   // exportPath string,
		m.bootstrapScriptPath,   // bootstrapScriptPath string,
		m.jobMountAddress,       // jobMountAddress string,
		m.jobExportPath,         // jobExportPath string,
		m.jobBasePath,           //jobBasePath string
	)

	customData, err := cacheWarmerCloudInit.GetCacheWarmerCloudInit()
	if err != nil {
		log.Error.Printf("BUG BUG: customData retrieval hits the following error: %v", err)
		return
	}

	vmssCount := int64(mountCount * NodesPerNFSMountAddress)

	cacheWarmerVmss := createCacheWarmerVmssModel(
		VmssName,                              // vmssName string,
		m.AzureClients.LocalMetadata.Location, // location string,
		VMSSNodeSize,                          // vmssSKU string,
		vmssCount,                             // nodeCount int64,
		m.vmssUserName,                        // userName string,
		m.vmssPassword,                        // password string,
		m.vmssSshPublicKey,                    // sshKeyData string,
		MarketPlacePublisher,                  // publisher string,
		MarketPlaceOffer,                      // offer string,
		MarketPlaceSku,                        // sku string,
		compute.Spot,                          // priority compute.VirtualMachinePriorityTypes,
		compute.Delete,                        // evictionPolicy compute.VirtualMachineEvictionPolicyTypes
		vmssSubnetId,                          // subnetId string
		customData,
	)

	log.Info.Printf("create VMSS with %d workers", vmssCount)
	if _, err := CreateVmss(ctx, m.AzureClients, cacheWarmerVmss); err != nil {
		log.Error.Printf("error creating vmss: %v", err)
		return
	}
}

func (m *WarmPathManager) EnsureVmssDeleted(ctx context.Context) {
	vmssExists, err := VmssExists(ctx, m.AzureClients, VmssName)
	if err != nil {
		log.Error.Printf("checking VMSS existence failed with error %v", err)
		return
	}
	if !vmssExists {
		log.Debug.Printf("vmss is already deleted")
		return
	}
	if err := DeleteVmss(ctx, m.AzureClients, VmssName); err != nil {
		log.Error.Printf("error deleting vmss: %v", err)
		return
	}
}
