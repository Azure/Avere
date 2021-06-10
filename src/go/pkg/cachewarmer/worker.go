// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"context"
	"fmt"
	"io"
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
	Queues    *CacheWarmerQueues
	workQueue *WorkQueue
}

// InitializeWorker initializes the job submitter structure
func InitializeWorker(queues *CacheWarmerQueues) *Worker {
	return &Worker{
		Queues:    queues,
		workQueue: InitializeWorkQueue(),
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
					workerJob, err := w.Queues.GetWorkerJob()
					if err != nil {
						log.Error.Printf("error checking worker job queue: %v", err)
						continue
					}
					if workerJob == nil {
						continue
					}
					if err := w.processWorkerJob(ctx, workerJob); err != nil {
						log.Error.Printf("error processing worker job: %v", err)
						continue
					}
					if err := w.Queues.DeleteWorkerJob(workerJob); err != nil {
						log.Error.Printf("error deleting worker job: %v", err)
						continue
					}
				}
			}
		}
	}
}

func (w *Worker) processWorkerJob(ctx context.Context, workerJob *WorkerJob) error {
	log.Debug.Printf("[Worker.processWorkerJob")
	defer log.Debug.Printf("Worker.processWorkerJob]")

	localPaths, err := w.mountAllWorkingPaths(workerJob)
	if err != nil {
		return fmt.Errorf("error mounting working paths: %v", err)
	}

	// randomly choose a mount path
	readPath := localPaths[rand.Intn(len(localPaths))]

	// is the workitem a file or directory
	isDirectory, err := IsDirectory(readPath)
	if err != nil {
		return fmt.Errorf("error determining type of path '%s': '%v'", readPath, err)
	}

	if isDirectory {
		log.Info.Printf("Queueing work items for directory %s", readPath)
		f, err := os.Open(readPath)
		if err != nil {
			return fmt.Errorf("error reading files from directory '%s': '%v'", readPath, err)
		}
		defer f.Close()
		lastRefreshVisibility := time.Now()
		workItemsQueued := 0
		for {
			// refresh the invisibility timer, so no-one steals it
			if time.Since(lastRefreshVisibility) > refreshWorkInterval {
				lastRefreshVisibility = time.Now()
				if err := w.Queues.StillProcessingWorkerJob(workerJob); err != nil {
					log.Error.Printf("error refreshing queue item: '%v'", err)
				}

			}
			dirEntries, err := f.Readdir(MinimumJobsOnDirRead)

			if len(dirEntries) == 0 && err == io.EOF {
				log.Info.Printf("finished reading directory '%s'", readPath)
				break
			}

			if err != nil && err != io.EOF {
				log.Error.Printf("error reading directory from directory '%s': '%v'", readPath, err)
				break
			}

			filteredFilenames := workerJob.FilterFiles(dirEntries)
			if len(filteredFilenames) > 0 {
				workItemsQueued += w.QueueWork(localPaths, filteredFilenames)
			}

			// verify that cancellation has not occurred
			if isCancelled(ctx) {
				break
			}
		}
		if workItemsQueued > 0 {
			log.Info.Printf("add %d jobs to the work queue [%d mounts]", workItemsQueued, len(localPaths))
		}
	} else if workerJob.StartByte == allFilesOrBytes || workerJob.StopByte == allFilesOrBytes {
		log.Info.Printf("Queueing work item for file %s", readPath)
		fileToWarm := InitializeFileToWarm(readPath, allFilesOrBytes, allFilesOrBytes)
		w.workQueue.AddWorkItem(fileToWarm)
	} else {
		// queue the file for read
		for i := workerJob.StartByte; i < workerJob.StopByte; i += MinimumSingleFileSize {
			end := i + MinimumSingleFileSize
			if end > workerJob.StopByte {
				end = workerJob.StopByte
			}
			log.Info.Printf("Queueing work item for file %s [%d,%d)", readPath, i, end)
			fileToWarm := InitializeFileToWarm(readPath, i, end)
			w.workQueue.AddWorkItem(fileToWarm)
		}
	}
	return nil
}

func (w *Worker) mountAllWorkingPaths(workerJob *WorkerJob) ([]string, error) {
	localPaths := make([]string, 0, len(workerJob.WarmTargetMountAddresses))
	for _, warmTargetMountAddress := range workerJob.WarmTargetMountAddresses {
		if localPath, err := EnsureWarmPath(warmTargetMountAddress, workerJob.WarmTargetExportPath, workerJob.WarmTargetPath); err == nil {
			localPaths = append(localPaths, localPath)
		} else {
			return nil, fmt.Errorf("error warming path '%s' '%s' '%s'", warmTargetMountAddress, workerJob.WarmTargetExportPath, workerJob.WarmTargetPath)
		}
	}
	return localPaths, nil
}

func (w *Worker) QueueWork(localPaths []string, filenames []string) int {
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
			fileToWarm := InitializeFileToWarm(fullPath, allFilesOrBytes, allFilesOrBytes)
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
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if time.Since(lastJobCheckTime) > timeBetweenWorkerJobCheck {
				lastJobCheckTime = time.Now()
				for {
					if w.workQueue.IsEmpty() {
						break
					} else {
						beforeJob := time.Now()
						w.processWorkItem(ctx)
						afterJob := time.Now()
						log.Info.Printf("time since processing last job %v, time to run job %v, jobcount %d\n", beforeJob.Sub(idleStart), afterJob.Sub(beforeJob), w.workQueue.WorkItemCount())
						idleStart = afterJob
					}
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
