// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"math/rand"
	"os"
	"path"
	"runtime"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

// Worker contains the information for the worker
type Worker struct {
	JobWorkerPath string
	workQueue     *WorkQueue
	workAvailable bool
}

// InitializeWorker initializes the job submitter structure
func InitializeWorker(jobWorkerPath string) *Worker {
	return &Worker{
		JobWorkerPath: jobWorkerPath,
		workQueue:     InitializeWorkQueue(),
	}
}

func (w *Worker) RunWorkerManager(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	defer syncWaitGroup.Done()
	log.Debug.Printf("[Worker.RunWorkerManager")
	defer log.Debug.Printf("Worker.RunWorkerManager]")

	// initialize random generator
	rand.Seed(time.Now().Unix())

	lastJobCheckTime := time.Now().Add(-timeBetweenWorkerJobCheck)
	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	workerCount := WorkerMultiplier * runtime.NumCPU()
	log.Info.Printf("starting %d orchestrator goroutines", workerCount)
	for i := 0; i < workerCount; i++ {
		syncWaitGroup.Add(1)
		go w.worker(ctx, syncWaitGroup)
	}

	// run the infinite loop
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if time.Since(lastJobCheckTime) > timeBetweenWorkerJobCheck || w.workAvailable {
				lastJobCheckTime = time.Now()
				if w.workQueue.IsEmpty() {
					workingFile := w.GetNextWorkItem()
					if workingFile != nil {
						w.workAvailable = true
						w.fillWorkQueue(ctx, workingFile)
					} else {
						w.workAvailable = false
					}

				}
			}
		}
	}
}

func (w *Worker) GetNextWorkItem() *WorkingFile {
	log.Debug.Printf("[Worker.getNextWorkItem")
	defer log.Debug.Printf("Worker.getNextWorkItem]")
	f, err := os.Open(w.JobWorkerPath)
	if err != nil {
		log.Error.Printf("error reading files from directory '%s': '%v'", w.JobWorkerPath, err)
		return nil
	}
	defer f.Close()
	lockedPaths := make([]string, 0, LockedWorkItemStartSliceSize)

	for files, err := f.Readdir(WorkerReadFilesAtOnce); len(files) > 0 || (err != nil && err != io.EOF); files, err = f.Readdir(WorkerReadFilesAtOnce) {
		if err != nil && err != io.EOF {
			log.Error.Printf("error reading dirnames from directory '%s': '%v'", w.JobWorkerPath, err)
			return nil
		}
		// to avoid collisions randomly choose a startIndex
		startIndex := rand.Intn(len(files))
		for i := 0; i < len(files); i++ {
			f := files[(startIndex+i)%len(files)]
			filepath := path.Join(w.JobWorkerPath, f.Name())
			if !Locked(filepath) {
				if workingFile := w.TrySetCurrentWorkingFile(filepath); workingFile != nil {
					return workingFile
				}
			} else {
				lockedPaths = append(lockedPaths, filepath)
			}
		}
	}
	// iterate through the locked paths to see if one can be stolen
	for _, lockedPath := range lockedPaths {
		// if age of locked Path > 2 minutes, steal the file
		if IsStale(lockedPath) {
			if workingFile := w.TrySetCurrentWorkingFile(lockedPath); workingFile != nil {
				return workingFile
			}
		}
	}
	return nil
}

// TrySetCurrentWorkingFile will try to lock the path and return the locked path
func (w *Worker) TrySetCurrentWorkingFile(filepath string) *WorkingFile {
	lockedFilePath, isLocked := LockPath(filepath)
	if isLocked {
		workerJob, err := ReadJobWorkerFile(lockedFilePath)
		if err != nil {
			log.Error.Printf("error reading file '%s': '%v'", lockedFilePath, err)
			return nil
		}
		return InitializeWorkingFile(lockedFilePath, workerJob)
	}
	return nil
}

func ReadJobWorkerFile(lockedFilePath string) (*WorkerJob, error) {
	log.Debug.Printf("[Worker.ReadJobWorkerFile")
	defer log.Debug.Printf("Worker.ReadJobWorkerFile]")
	byteContent, err := ioutil.ReadFile(lockedFilePath)
	if err != nil {
		if err2 := os.Remove(lockedFilePath); err != nil {
			return nil, fmt.Errorf("error removing locked file during other error '%s': '%v' '%v'", lockedFilePath, err2, err)
		}
		return nil, fmt.Errorf("error processing locked file '%s': %v", lockedFilePath, err)
	}

	warmPathJob, err := InitializeWorkerJobFromString(string(byteContent))
	if err != nil {
		if err2 := os.Remove(lockedFilePath); err != nil {
			return nil, fmt.Errorf("error removing locked file during other error '%s': '%v' '%v'", lockedFilePath, err2, err)
		}
		return nil, fmt.Errorf("error initializing worker job from locked file '%s': %v", lockedFilePath, err)
	}
	return warmPathJob, nil
}

func (w *Worker) mountAllWorkingPaths(workingFile *WorkingFile) ([]string, error) {
	localPaths := make([]string, 0, len(workingFile.workerJob.WarmTargetMountAddresses))
	for _, warmTargetMountAddress := range workingFile.workerJob.WarmTargetMountAddresses {
		if localPath, err := EnsureWarmPath(warmTargetMountAddress, workingFile.workerJob.WarmTargetExportPath, workingFile.workerJob.WarmTargetPath); err == nil {
			localPaths = append(localPaths, localPath)
		} else {
			return nil, fmt.Errorf("error warming path '%s' '%s' '%s'", warmTargetMountAddress, workingFile.workerJob.WarmTargetExportPath, workingFile.workerJob.WarmTargetPath)
		}
	}
	return localPaths, nil
}

func (w *Worker) fillWorkQueue(ctx context.Context, workingFile *WorkingFile) {
	log.Debug.Printf("[Worker.fillWorkQueue")
	defer log.Debug.Printf("Worker.fillWorkQueue]")

	localPaths, err := w.mountAllWorkingPaths(workingFile)
	if err != nil {
		log.Error.Printf("error mounting working paths: %v", err)
		return
	}

	// randomly choose a mount path
	readPath := localPaths[rand.Intn(len(localPaths))]

	// is the workitem a file or directory
	isDirectory, err := IsDirectory(readPath)
	if err != nil {
		log.Error.Printf("error determining type of path '%s': '%v'", readPath, err)
		return
	}

	if isDirectory {
		log.Info.Printf("Queueing work items for directory %s", readPath)
		f, err := os.Open(readPath)
		if err != nil {
			log.Error.Printf("error reading files from directory '%s': '%v'", readPath, err)
			return
		}
		defer f.Close()
		workItemsQueued := 0
		for {
			files, err := f.Readdir(WorkerReadFilesAtOnce)
			// touch file between reads
			go workingFile.TouchFile()

			if len(files) == 0 && err == io.EOF {
				log.Info.Printf("finished reading directory '%s'", readPath)
				break
			}

			if err != nil && err != io.EOF {
				log.Error.Printf("error reading dirnames from directory '%s': '%v'", readPath, err)
				break
			}

			workItemsQueued += w.QueueWork(localPaths, files, workingFile)

			// verify that cancellation has not occurred
			if isCancelled(ctx) {
				break
			}
		}
		if workItemsQueued > 0 {
			log.Info.Printf("add %d jobs to the work queue [%d mounts]", workItemsQueued, len(localPaths))
		} else {
			log.Info.Printf("no items added to the work queue, proceeding to delete job file")
			workingFile.FileProcessed()
		}

	} else {
		// queue the file for read
		log.Info.Printf("Queueing work item for file %s", readPath)
		filesToWarm := []FileToWarm{InitializeFileToWarm(readPath, workingFile)}
		w.workQueue.AddWork(filesToWarm)
	}
}

func (w *Worker) QueueWork(localPaths []string, fileInfos []os.FileInfo, workingFile *WorkingFile) int {
	filesToWarm := make([]FileToWarm, 0, len(fileInfos))
	for _, fileInfo := range fileInfos {
		if !fileInfo.IsDir() && fileInfo.Size() < MinimumSingleFileSize {
			randomPath := localPaths[rand.Intn(len(localPaths))]
			fullPath := path.Join(randomPath, fileInfo.Name())
			filesToWarm = append(filesToWarm, InitializeFileToWarm(fullPath, workingFile))
		}
	}
	if len(filesToWarm) > 0 {
		w.workQueue.AddWork(filesToWarm)
	}
	return len(filesToWarm)
}

func (w *Worker) worker(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	defer syncWaitGroup.Done()
	log.Info.Printf("[worker")
	defer log.Info.Printf("completed worker]")

	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			for {
				if w.workQueue.IsEmpty() {
					continue
				}
				w.processWorkItem(ctx)
				if isCancelled(ctx) {
					return
				}
			}
		}
	}
}

func (w *Worker) processWorkItem(ctx context.Context) {
	fileToWarm, workExists := w.workQueue.GetNextWorkItem()
	if !workExists {
		return
	}
	w.readFile(ctx, fileToWarm)
}

func (w *Worker) readFile(ctx context.Context, fileToWarm FileToWarm) {
	defer fileToWarm.ParentJobFile.FileProcessed()
	var readBytes int
	file, err := os.Open(fileToWarm.WarmFileFullPath)
	if err != nil {
		log.Error.Printf("error opening file %s: %v", fileToWarm.WarmFileFullPath, err)
		return
	}
	defer file.Close()
	buffer := make([]byte, ReadPageSize)
	lastCancelCheckTime := time.Now()
	for {
		count, err := file.Read(buffer)
		readBytes += count
		if err != nil {
			if err != io.EOF {
				log.Error.Printf("error reading file %s: %v", fileToWarm.WarmFileFullPath, err)
			}
			log.Info.Printf("read %d bytes from filepath %s", readBytes, fileToWarm.WarmFileFullPath)
			return
		}
		go fileToWarm.ParentJobFile.TouchFile()
		// ensure no cancel
		if time.Since(lastCancelCheckTime) > timeBetweenCancelCheck {
			lastCancelCheckTime = time.Now()
			if isCancelled(ctx) {
				return
			}
		}
	}
}
