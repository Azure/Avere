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
	"github.com/Azure/azure-sdk-for-go/profiles/2020-09-01/compute/mgmt/compute"
)

// WarmPathManager contains the information for the manager
type WarmPathManager struct {
	AzureClients          *AzureClients
	WorkerCount           int64
	Queues                *CacheWarmerQueues
	bootstrapMountAddress string
	bootstrapExportPath   string
	bootstrapScriptPath   string
	vmssUserName          string
	vmssPassword          string
	vmssSshPublicKey      string
	vmssSubnet            string
	storageAccount        string
	storageKey            string
	queueNamePrefix       string
}

// InitializeWarmPathManager initializes the job submitter structure
func InitializeWarmPathManager(
	azureClients *AzureClients,
	workerCount int64,
	queues *CacheWarmerQueues,
	bootstrapMountAddress string,
	bootstrapExportPath string,
	bootstrapScriptPath string,
	vmssUserName string,
	vmssPassword string,
	vmssSshPublicKey string,
	vmssSubnet string,
	storageAccount string,
	storageKey string,
	queueNamePrefix string) *WarmPathManager {
	return &WarmPathManager{
		AzureClients:          azureClients,
		WorkerCount:           workerCount,
		Queues:                queues,
		bootstrapMountAddress: bootstrapMountAddress,
		bootstrapExportPath:   bootstrapExportPath,
		bootstrapScriptPath:   bootstrapScriptPath,
		vmssUserName:          vmssUserName,
		vmssPassword:          vmssPassword,
		vmssSshPublicKey:      vmssSshPublicKey,
		vmssSubnet:            vmssSubnet,
		storageAccount:        storageAccount,
		storageKey:            storageKey,
		queueNamePrefix:       queueNamePrefix,
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
				log.Info.Printf("check jobs in queue")
				for {
					warmPathJob, err := m.Queues.GetWarmPathJob()
					if err != nil {
						log.Error.Printf("error checking job queue: %v", err)
						break
					}
					if warmPathJob == nil {
						break
					}
					if err := m.processJob(ctx, warmPathJob); err != nil {
						log.Error.Printf("error encountered processing job: %v", err)
						break
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

func (m *WarmPathManager) processJob(ctx context.Context, warmPathJob *WarmPathJob) error {
	id, popReceipt := warmPathJob.GetQueueMessageInfo()
	log.Info.Printf("[WarmPathManager.processJob '%s' '%s'", id, popReceipt)
	defer log.Info.Printf("WarmPathManager.processJob '%s' '%s']", id, popReceipt)

	if len(warmPathJob.WarmTargetMountAddresses) == 0 {
		if err := m.Queues.DeleteWarmPathJob(warmPathJob); err != nil {
			log.Error.Printf("error removing job: %v", err)
		}
		return fmt.Errorf("there are no mount addresses specified in the job")
	}

	localMountPath := GetLocalMountPath(warmPathJob.WarmTargetMountAddresses[0], warmPathJob.WarmTargetExportPath)
	if err := MountPath(warmPathJob.WarmTargetMountAddresses[0], warmPathJob.WarmTargetExportPath, localMountPath); err != nil {
		return fmt.Errorf("error trying to mount %s:%s: %v", warmPathJob.WarmTargetMountAddresses[0], warmPathJob.WarmTargetExportPath, err)
	}

	log.Status.Printf("start processing %s", warmPathJob.WarmTargetPath)
	defer log.Status.Printf("stop processing %s", warmPathJob.WarmTargetPath)

	lastRefreshVisibility := time.Now()
	folderSlice := []string{warmPathJob.WarmTargetPath}
	for len(folderSlice) > 0 {
		// check for cancelation between files
		if isCancelled(ctx) {
			log.Info.Printf("cancelation occurred while processing job files")
			return nil
		}
		if time.Since(lastRefreshVisibility) > refreshWorkInterval {
			lastRefreshVisibility = time.Now()
			m.Queues.StillProcessingWarmPathJob(warmPathJob)
		}

		// dequeue the next folder
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

		files, largeFiles, dirs := processDirEntries(dirEntries, warmPathJob)

		// queue the directories
		for _, dir := range dirs {
			folderSlice = append(folderSlice, path.Join(warmFolder, dir.Name()))
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
				log.Info.Printf("queuing worker job for file %s [%d,%d)", fullPath, i, end)
				workerJob := InitializeWorkerJobForLargeFile(warmPathJob.WarmTargetMountAddresses, warmPathJob.WarmTargetExportPath, fullPath, i, end, warmPathJob.InclusionList, warmPathJob.ExclusionList, warmPathJob.MaxFileSizeBytes)
				if err := m.Queues.WriteWorkerJob(workerJob); err != nil {
					log.Error.Printf("error encountered writing worker job '%s': %v", fullPath, err)
				}
			}
		}

		// write a job for each group of files
		if len(files) > 0 {
			if len(files) < MaximumFilesToRead {
				log.Info.Printf("queuing job for path %s", warmFolder)
				workerJob := InitializeWorkerJob(warmPathJob.WarmTargetMountAddresses, warmPathJob.WarmTargetExportPath, warmFolder, warmPathJob.InclusionList, warmPathJob.ExclusionList, warmPathJob.MaxFileSizeBytes)
				if err := m.Queues.WriteWorkerJob(workerJob); err != nil {
					log.Error.Printf("error encountered writing worker job '%s': %v", warmFolder, err)
				}
			} else {
				for i := 0; i < len(files); i += MaximumFilesToRead {
					end := i + MaximumFilesToRead
					if end >= len(files) {
						end = len(files) - 1
					}
					log.Info.Printf("queuing job for path %s [%s,%s]", warmFolder, files[i].Name(), files[end].Name())
					workerJob := InitializeWorkerJobWithFilter(warmPathJob.WarmTargetMountAddresses, warmPathJob.WarmTargetExportPath, warmFolder, files[i].Name(), files[end].Name(), warmPathJob.InclusionList, warmPathJob.ExclusionList, warmPathJob.MaxFileSizeBytes)
					if err := m.Queues.WriteWorkerJob(workerJob); err != nil {
						log.Error.Printf("error encountered writing worker job %s [%s,%s]: %v", warmFolder, files[i].Name(), files[end].Name(), err)
					}
				}
			}
		}
	}

	// remove the job file
	if err := m.Queues.DeleteWarmPathJob(warmPathJob); err != nil {
		log.Error.Printf("error removing job '%s' '%s' at end of processing: %v", id, popReceipt, err)
	}

	return nil
}

func processDirEntries(dirEntries []os.FileInfo, warmPathJob *WarmPathJob) ([]os.FileInfo, []os.FileInfo, []os.FileInfo) {
	// bucketize the files into files, largeFiles, and dirs
	fileSizes := make([]int64, 0, len(dirEntries))
	files := make([]os.FileInfo, 0, len(dirEntries))
	largeFiles := make([]os.FileInfo, 0, len(dirEntries))
	dirs := make([]os.FileInfo, 0, len(dirEntries))

	for _, dirEntry := range dirEntries {
		if dirEntry.IsDir() {
			dirs = append(dirs, dirEntry)
		} else { /* !dirEntry.IsDir() */
			if !warmPathJob.FileMatches(dirEntry.Name(), dirEntry.Size()) {
				continue
			}
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

func (m *WarmPathManager) RunVMSSManager(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	log.Debug.Printf("[WarmPathManager.RunVMSSManager")
	defer log.Debug.Printf("WarmPathManager.RunVMSSManager]")
	defer syncWaitGroup.Done()

	lastWorkerJobCheckTime := time.Now().Add(-timeBetweenJobCheck)
	lastReadQueueSuccess := time.Now()
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
			if time.Since(lastWorkerJobCheckTime) > timeBetweenJobCheck {
				lastWorkerJobCheckTime = time.Now()
				log.Info.Printf("VMSS Manager check if worker jobs exist")
				if isEmpty, err := m.Queues.IsWorkQueueEmpty(); err != nil {
					log.Error.Printf("error checking if work queue was empty: %v", err)
					if time.Since(lastReadQueueSuccess) > failureTimeToDeleteVMSS {
						log.Error.Printf("read worker queue has not been successful for 15 minutes, ensure vmss deleted")
						m.EnsureVmssDeleted(ctx)
						// reset the last read dir success
						lastReadQueueSuccess = time.Now()
						continue
					}
				} else if isEmpty == true {
					// jobs do not exist, delete vmss if not already deleted
					if time.Since(lastJobSeen) > timeToDeleteVMSSAfterNoJobs {
						m.EnsureVmssDeleted(ctx)
					}
				} else {
					// jobs exist
					workerJob, err := m.Queues.PeekWorkerJob()
					if err != nil {
						log.Error.Printf("error peeking at a worker job: %v", err)
						continue
					}
					if workerJob == nil {
						continue
					}
					m.EnsureVmssRunning(ctx)
					lastJobSeen = time.Now()
				}
				lastReadQueueSuccess = time.Now()
			}
		}
	}
}

func (m *WarmPathManager) EnsureVmssRunning(ctx context.Context) {
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

	// get proxy information and pass on to worker
	httpProxyStr := ""
	if e := os.Getenv("http_proxy"); len(e) > 0 {
		httpProxyStr = fmt.Sprintf("http_proxy=%s", e)
	}
	httpsProxyStr := ""
	if e := os.Getenv("https_proxy"); len(e) > 0 {
		httpProxyStr = fmt.Sprintf("https_proxy=%s", e)
	}
	noProxyStr := ""
	if e := os.Getenv("no_proxy"); len(e) > 0 {
		noProxyStr = fmt.Sprintf("no_proxy=%s", e)
	}

	cacheWarmerCloudInit := InitializeCloutInit(
		httpProxyStr,            // httpProxyStr string,
		httpsProxyStr,           // httpsProxyStr string,
		noProxyStr,              // noProxyStr string,
		m.bootstrapMountAddress, // bootstrapAddress string,
		m.bootstrapExportPath,   // exportPath string,
		m.bootstrapScriptPath,   // bootstrapScriptPath string,
		m.storageAccount,        // storageAccount string,
		m.storageKey,            // storageKey string,
		m.queueNamePrefix,       // queueNamePrefix string
	)

	customData, err := cacheWarmerCloudInit.GetCacheWarmerCloudInit()
	if err != nil {
		log.Error.Printf("BUG BUG: customData retrieval hits the following error: %v", err)
		return
	}

	cacheWarmerVmss := createCacheWarmerVmssModel(
		VmssName,                              // vmssName string,
		m.AzureClients.LocalMetadata.Location, // location string,
		VMSSNodeSize,                          // vmssSKU string,
		m.WorkerCount,                         // nodeCount int64,
		m.vmssUserName,                        // userName string,
		m.vmssPassword,                        // password string,
		m.vmssSshPublicKey,                    // sshKeyData string,
		MarketPlacePublisher,                  // publisher string,
		MarketPlaceOffer,                      // offer string,
		MarketPlaceSku,                        // sku string,
		PlanName,                              // planName string,
		PlanPublisherName,                     // planPublisherName string,
		PlanProductName,                       // planProductName string,
		compute.Spot,                          // priority compute.VirtualMachinePriorityTypes,
		compute.Delete,                        // evictionPolicy compute.VirtualMachineEvictionPolicyTypes
		vmssSubnetId,                          // subnetId string
		customData,
	)

	log.Info.Printf("create VMSS with %d workers", m.WorkerCount)
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
