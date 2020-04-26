// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"

	"github.com/Azure/go-autorest/autorest"
)

// WarmPathManager contains the information for the manager
type WarmPathManager struct {
	Authorizer autorest.Authorizer
	JobSubmitterPath string
	JobWorkerPath string
}

// InitializeWarmPathManager initializes the job submitter structure
func InitializeWarmPathManager(
	authorizer autorest.Authorizer,
	jobSubmitterPath string,
	jobWorkerPath string) *WarmPathManager {
	return &WarmPathManager{
		Authorizer: authorizer,
		JobSubmitterPath: jobSubmitterPath,
		JobWorkerPath: jobWorkerPath,
	}
}

func (m *WarmPathManager) RunJobGenerator(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	log.Debug.Printf("[WarmPathManager.RunJobGenerator")
	defer log.Debug.Printf("WarmPathManager.RunJobGenerator]")
	defer syncWaitGroup.Done()

	lastJobCheckTime := time.Now().Add(-timeBetweenJobCheck)
	ticker := time.NewTicker(tick)
	defer ticker.Stop()

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
					if err := m.processJobFile(ctx, filename) ; err != nil {
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
	if err := MountPath(warmPathJob.WarmTargetMountAddresses[0], warmPathJob.WarmTargetExportPath, localMountPath) ; err != nil {
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
		for _, file := range(files) {
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
				log.Info.Printf("check worker jobs in path %s", m.JobWorkerPath)
			}
		}
	}
}

