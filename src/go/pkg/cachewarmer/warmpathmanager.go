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
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
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

		// write worker file
		workerJob := InitializeWorkerJob(warmPathJob.WarmTargetMountAddresses, warmPathJob.WarmTargetExportPath, warmFolder)
		workerJob.WriteJob(m.JobWorkerPath)

		// queue up additional folders
		fullWarmPath := path.Join(localMountPath, warmFolder)
		files, err := ioutil.ReadDir(fullWarmPath)
		if err != nil {
			log.Error.Printf("error encountered reading directory '%s': %v", warmFolder, err)
			continue
		}
		for _, file := range files {
			if file.IsDir() {
				if !isCacheWarmerFolder(file.Name()) {
					folderSlice = append(folderSlice, path.Join(warmFolder, file.Name()))
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

func isCacheWarmerFolder(folder string) bool {
	return folder == DefaultCacheJobSubmitterDir || folder == DefaultCacheWorkerJobsDir
}

func (m *WarmPathManager) RunVMSSManager(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	log.Debug.Printf("[WarmPathManager.RunVMSSManager")
	defer log.Debug.Printf("WarmPathManager.RunVMSSManager]")
	defer syncWaitGroup.Done()

	lastWorkerJobCheckTime := time.Now().Add(-timeBetweenWorkerJobCheck)
	lastReadDirSuccess := time.Now()
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
				lastReadDirSuccess = time.Now()

				if jobsExist {
					m.EnsureVmssRunning(ctx, mountCount)
				} else {
					m.EnsureVmssDeleted(ctx)
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
	localVMSubnetId, err := GetSubnetId(ctx, m.AzureClients)
	if err != nil {
		log.Error.Printf("ERROR: failed to initialize Azure Clients: %s", err)
		return
	}
	vmssSubnetId := SwapResourceName(localVMSubnetId, m.vmssSubnet)

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
