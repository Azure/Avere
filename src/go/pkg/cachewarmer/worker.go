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
	JobWorkerPath      string
	workQueue          *WorkQueue
	readerCounter      *ReaderCounter
	currentWorkingFile string
	currentWorkJob     *WorkerJob
}

// InitializeWorker initializes the job submitter structure
func InitializeWorker(jobWorkerPath string) *Worker {
	return &Worker{
		JobWorkerPath: jobWorkerPath,
		workQueue:     InitializeWorkQueue(),
		readerCounter: InitializeReaderCounter(),
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
			if (time.Since(lastJobCheckTime) > timeBetweenWorkerJobCheck) || (w.workQueue.IsEmpty() && w.readerCounter.ReadersEmpty() && w.ProcessingFile()) {
				lastJobCheckTime = time.Now()
				if w.workQueue.IsEmpty() && w.readerCounter.ReadersEmpty() {
					if w.ProcessingFile() {
						w.CompleteProcessingFile()
					}
					w.GetNextWorkItem()
					if w.ProcessingFile() {
						TouchFile(w.currentWorkingFile)
						w.fillWorkQueue(ctx)
					}
				} else if w.ProcessingFile() {
					TouchFile(w.currentWorkingFile)
				}
			}
		}
	}
}

func (w *Worker) ProcessingFile() bool {
	return w.currentWorkingFile != ""
}

func (w *Worker) CompleteProcessingFile() {
	if w.currentWorkingFile != "" && w.currentWorkJob != nil {
		log.Info.Printf("finished processing directory '%s'", w.currentWorkJob.WarmTargetPath)
		if err := os.Remove(w.currentWorkingFile); err != nil {
			log.Error.Printf("error removing working file '%s': '%v'", w.currentWorkingFile, err)
		}
	}

	w.currentWorkingFile = ""
	w.currentWorkJob = nil
}

func (w *Worker) GetNextWorkItem() {
	log.Debug.Printf("[Worker.getNextWorkItem")
	defer log.Debug.Printf("Worker.getNextWorkItem]")
	f, err := os.Open(w.JobWorkerPath)
	if err != nil {
		log.Error.Printf("error reading files from directory '%s': '%v'", w.JobWorkerPath, err)
		return
	}
	defer f.Close()
	lockedPaths := make([]string, 0, LockedWorkItemStartSliceSize)
	for {
		files, err := f.Readdir(WorkerReadFilesAtOnce)
		if len(files) == 0 && err == io.EOF {
			break
		}
		if err != nil && err != io.EOF {
			log.Error.Printf("error reading dirnames from directory '%s': '%v'", w.JobWorkerPath, err)
			return
		}
		for _, f := range files {
			filepath := path.Join(w.JobWorkerPath, f.Name())
			if !Locked(filepath) {
				if filelocked := w.TrySetCurrentWorkingFile(filepath); filelocked {
					return
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
			if filelocked := w.TrySetCurrentWorkingFile(lockedPath); filelocked {
				return
			}
		}
	}
}

// TrySetCurrentWorkingFile will try to lock the path and then set the current working job
func (w *Worker) TrySetCurrentWorkingFile(filepath string) bool {
	lockedFilePath, isLocked := LockPath(filepath)
	if isLocked {
		workerJob, err := ReadJobWorkerFile(lockedFilePath)
		if err != nil {
			log.Error.Printf("error reading file '%s': '%v'", lockedFilePath, err)
			return false
		}
		w.currentWorkingFile = lockedFilePath
		w.currentWorkJob = workerJob
		return true
	}
	return false
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

func (w *Worker) mountAllWorkingPaths() ([]string, error) {
	localPaths := make([]string, 0, len(w.currentWorkJob.WarmTargetMountAddresses))
	for _, warmTargetMountAddress := range w.currentWorkJob.WarmTargetMountAddresses {
		if localPath, err := EnsureWarmPath(warmTargetMountAddress, w.currentWorkJob.WarmTargetExportPath, w.currentWorkJob.WarmTargetPath); err == nil {
			localPaths = append(localPaths, localPath)
		} else {
			return nil, fmt.Errorf("error warming path '%s' '%s' '%s'", warmTargetMountAddress, w.currentWorkJob.WarmTargetExportPath, w.currentWorkJob.WarmTargetPath)
		}
	}
	return localPaths, nil
}

func (w *Worker) fillWorkQueue(ctx context.Context) {
	log.Debug.Printf("[Worker.fillWorkQueue")
	defer log.Debug.Printf("Worker.fillWorkQueue]")

	localPaths, err := w.mountAllWorkingPaths()
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
		for {
			files, err := f.Readdir(WorkerReadFilesAtOnce)
			// touch file between reads
			TouchFile(w.currentWorkingFile)

			if len(files) == 0 && err == io.EOF {
				log.Info.Printf("finished reading directory '%s'", readPath)
				return
			}

			if err != nil && err != io.EOF {
				log.Error.Printf("error reading dirnames from directory '%s': '%v'", readPath, err)
				return
			}

			w.QueueWork(localPaths, files)

			// verify that cancellation has not occurred
			if isCancelled(ctx) {
				return
			}
		}
	} else {
		// queue the file for read
		log.Info.Printf("Queueing work items for file %s", readPath)
		filePaths := []string{readPath}
		w.workQueue.AddWork(filePaths)
	}
}

func (w *Worker) QueueWork(localPaths []string, fileInfos []os.FileInfo) {
	filePaths := make([]string, 0, len(fileInfos)*len(localPaths))
	for _, fileInfo := range fileInfos {
		if !fileInfo.IsDir() && fileInfo.Size() < MinimumSingleFileSize {
			randomPath := localPaths[rand.Intn(len(localPaths))]
			filePaths = append(filePaths, path.Join(randomPath, fileInfo.Name()))

			/* the below is only useful if always_forwad is turned off
			// add a filepath for each mount path
			for _, localPath := range localPaths {
				filePaths = append(filePaths, path.Join(localPath, fileInfo.Name()))
			}*/
		}
	}
	log.Info.Printf("add %d jobs to the work queue [%d mounts]", len(filePaths), len(localPaths))
	w.workQueue.AddWork(filePaths)
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
	// try to grab the work item, counting self as reader
	w.readerCounter.AddReader()
	defer w.readerCounter.RemoveReader()
	workItem, workExists := w.workQueue.GetNextWorkItem()
	if !workExists {
		return
	}
	w.readFile(ctx, workItem)
}

func (w *Worker) readFile(ctx context.Context, filepath string) {
	var readBytes int
	file, err := os.Open(filepath)
	if err != nil {
		log.Error.Printf("error opening file %s: %v", filepath, err)
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
				log.Error.Printf("error reading file %s: %v", filepath, err)
			}
			log.Debug.Printf("read %d bytes from filepath %s", readBytes, filepath)
			return
		}
		// ensure no cancel
		if time.Since(lastCancelCheckTime) > timeBetweenCancelCheck {
			lastCancelCheckTime = time.Now()
			if isCancelled(ctx) {
				return
			}
		}
	}
}
