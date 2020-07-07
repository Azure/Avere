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
	jobFileReader *JobFileReader
}

// InitializeWorker initializes the job submitter structure
func InitializeWorker(jobWorkerPath string) *Worker {
	return &Worker{
		JobWorkerPath: jobWorkerPath,
		workQueue:     InitializeWorkQueue(),
		jobFileReader: NewJobFileReader(jobWorkerPath),
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

	workAvailable := false
	// run the infinite loop
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if time.Since(lastJobCheckTime) > timeBetweenWorkerJobCheck || workAvailable {
				lastJobCheckTime = time.Now()
				workItemCount := w.workQueue.WorkItemCount()

				if workItemCount < MinimumJobsBeforeRefill {
					workAvailable = w.GetMoreWork(ctx)
				}
			}
		}
	}
}

func GetMoreWorkFinish(start time.Time) {
	log.Info.Printf("Worker.getNextWorkItem took %v]", time.Now().Sub(start))
}

func (w *Worker) GetMoreWork(ctx context.Context) bool {
	log.Info.Printf("[Worker.getNextWorkItem")
	start := time.Now()
	defer GetMoreWorkFinish(start)

	workAvailable := false
	begin := time.Now()
	workingFile := w.GetNextWorkItem(ctx)
	log.Info.Printf("GetNextWorkItem took %v", time.Now().Sub(begin))
	if workingFile != nil {
		workAvailable = true
		begin = time.Now()
		w.fillWorkQueue(ctx, workingFile)
		log.Info.Printf("FillWorkItem took %v", time.Now().Sub(begin))
	} else {
		log.Info.Printf("work item count %d, setting work available to false", w.workQueue.WorkItemCount())
		workAvailable = false
	}
	return workAvailable
}

func (w *Worker) GetNextWorkItem(ctx context.Context) *WorkingFile {
	log.Debug.Printf("[Worker.getNextWorkItem")
	defer log.Debug.Printf("Worker.getNextWorkItem]")

	filenameSeen := make(map[string]bool)

	lockedPaths := make([]string, 0, LockedWorkItemStartSliceSize)
	for !isCancelled(ctx) {
		nextFilename := w.jobFileReader.GetNextFilename()
		if len(nextFilename) == 0 {
			return nil
		}
		// verify the the job file reader has not looped
		if _, ok := filenameSeen[nextFilename]; ok {
			break
		}
		filenameSeen[nextFilename] = true

		filepath := path.Join(w.JobWorkerPath, nextFilename)
		isDirectory, err := IsDirectory(filepath)
		if err != nil {
			log.Error.Printf("error querying directory on '%s': %v", filepath, err)
			continue
		}
		if isDirectory {
			continue
		}
		if !Locked(filepath) {
			begin := time.Now()
			if workingFile := w.TrySetCurrentWorkingFile(filepath); workingFile != nil {
				log.Info.Printf("TrySetCurrentWorkingFile took %v", time.Now().Sub(begin))
				return workingFile
			}
		} else {
			lockedPaths = append(lockedPaths, filepath)
		}
	}
	// iterate through the locked paths to see if one can be stolen
	for _, lockedPath := range lockedPaths {
		// if age of locked Path > 2 minutes, steal the file
		begin := time.Now()
		isStale := IsStale(lockedPath)
		log.Info.Printf("IsStale took %v", time.Now().Sub(begin))
		if isStale {
			begin = time.Now()
			if workingFile := w.TrySetCurrentWorkingFile(lockedPath); workingFile != nil {
				log.Info.Printf("TrySetCurrentWorkingFile took %v", time.Now().Sub(begin))
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
			filenames, err := f.Readdirnames(MinimumJobsOnDirRead)
			// touch file between reads
			go workingFile.TouchFile()

			if len(filenames) == 0 && err == io.EOF {
				log.Info.Printf("finished reading directory '%s'", readPath)
				break
			}

			if err != nil && err != io.EOF {
				log.Error.Printf("error reading dirnames from directory '%s': '%v'", readPath, err)
				break
			}

			filteredFilenames := workingFile.workerJob.FilterFiles(filenames)
			if len(filteredFilenames) > 0 {
				workItemsQueued += w.QueueWork(localPaths, filteredFilenames, workingFile)
			}

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
	} else if workingFile.workerJob.StartByte == allFilesOrBytes || workingFile.workerJob.StopByte == allFilesOrBytes {
		log.Info.Printf("Queueing work item for file %s", readPath)
		fileToWarm := InitializeFileToWarm(readPath, workingFile, allFilesOrBytes, allFilesOrBytes)
		w.workQueue.AddWorkItem(fileToWarm)
	} else {
		// queue the file for read
		for i := workingFile.workerJob.StartByte; i < workingFile.workerJob.StopByte; i += MinimumSingleFileSize {
			end := i + MinimumSingleFileSize
			if end > workingFile.workerJob.StopByte {
				end = workingFile.workerJob.StopByte
			}
			log.Info.Printf("Queueing work item for file %s [%d,%d)", readPath, i, end)
			fileToWarm := InitializeFileToWarm(readPath, workingFile, i, end)
			w.workQueue.AddWorkItem(fileToWarm)
		}
	}
}

func (w *Worker) QueueWork(localPaths []string, filenames []string, workingFile *WorkingFile) int {
	itemsQueued := 0
	for _, filename := range filenames {
		randomPath := localPaths[rand.Intn(len(localPaths))]
		fullPath := path.Join(randomPath, filename)
		fileInfo, err := os.Stat(fullPath)
		if err != nil {
			log.Error.Printf("os.Stat(%s) return error '%v'", fullPath, err)
			continue
		}
		if !fileInfo.IsDir() && fileInfo.Size() < MinimumSingleFileSize {
			fileToWarm := InitializeFileToWarm(fullPath, workingFile, allFilesOrBytes, allFilesOrBytes)
			w.workQueue.AddWorkItem(fileToWarm)
			itemsQueued++
		}
	}
	return itemsQueued
}

func (w *Worker) worker(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	defer syncWaitGroup.Done()
	log.Info.Printf("[worker")
	defer log.Info.Printf("completed worker]")

	ticker := time.NewTicker(tick)
	defer ticker.Stop()
	idleStart := time.Now()

	lastJobCheckTime := time.Now().Add(-timeBetweenWorkerJobCheck)
	workAvailable := false

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			for {
				if w.workQueue.IsEmpty() {
					if time.Since(lastJobCheckTime) > timeBetweenWorkerJobCheck || workAvailable {
						lastJobCheckTime = time.Now()
						workAvailable = w.GetMoreWork(ctx)
					} else {
						break
					}
				} else {
					beforeJob := time.Now()
					w.processWorkItem(ctx)
					afterJob := time.Now()
					log.Info.Printf("time since processing last job %v, time to run job %v, jobcount %d\n", beforeJob.Sub(idleStart), afterJob.Sub(beforeJob), w.workQueue.WorkItemCount())
					idleStart = afterJob
					if isCancelled(ctx) {
						return
					}
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
	if fileToWarm.StartByte == allFilesOrBytes || fileToWarm.StopByte == allFilesOrBytes {
		w.readFileFull(ctx, fileToWarm)
	} else {
		w.readFilePartial(ctx, fileToWarm)
	}
}

func (w *Worker) readFileFull(ctx context.Context, fileToWarm FileToWarm) {
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

func (w *Worker) readFilePartial(ctx context.Context, fileToWarm FileToWarm) {
	defer fileToWarm.ParentJobFile.FileProcessed()
	if fileToWarm.StartByte == allFilesOrBytes || fileToWarm.StopByte == allFilesOrBytes {
		log.Error.Printf("error no startbyte or stop byte set for partial read")
		return
	}

	var readBytes int
	file, err := os.Open(fileToWarm.WarmFileFullPath)
	if err != nil {
		log.Error.Printf("error opening file %s: %v", fileToWarm.WarmFileFullPath, err)
		return
	}
	defer file.Close()
	buffer := make([]byte, ReadPageSize)
	lastCancelCheckTime := time.Now()

	for currentByte := fileToWarm.StartByte; currentByte < fileToWarm.StopByte; currentByte = fileToWarm.StartByte + int64(readBytes) {
		count, err := file.ReadAt(buffer, currentByte)
		readBytes += count
		if err != nil {
			if err != io.EOF {
				log.Error.Printf("error reading file %s: %v", fileToWarm.WarmFileFullPath, err)
			}
			break
		}
		go fileToWarm.ParentJobFile.TouchFile()
		// ensure no cancel
		if time.Since(lastCancelCheckTime) > timeBetweenCancelCheck {
			lastCancelCheckTime = time.Now()
			if isCancelled(ctx) {
				break
			}
		}
	}

	log.Info.Printf("read %d bytes from filepath %s [%d,%d)", readBytes, fileToWarm.WarmFileFullPath, fileToWarm.StartByte, fileToWarm.StopByte)
}
