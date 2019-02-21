// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package edasim

import (
	"context"
	"fmt"
	"path"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/file"
	"github.com/Azure/Avere/src/go/pkg/log"
)

const (
	tick                  = time.Duration(10) * time.Millisecond // 10ms
	timeBetweenQueueCheck = time.Duration(5) * time.Second       // 1 second between checking queues
	QueueMessageCount     = 1
)

// JobSubmitter defines the structure used for the job submitter process
type JobSubmitter struct {
	Context       context.Context
	UniqueName    string
	JobRunQueue   *azure.Queue
	JobStartQueue *azure.Queue
	ThreadCount   int
	PathManager   *file.RoundRobinPathManager
	DirManager    *file.DirectoryManager
}

// InitializeJobSubmitter initializes the job submitter structure
func InitializeJobSubmitter(
	ctx context.Context,
	storageAccount string,
	storageKey string,
	uniqueName string,
	mountPaths []string,
	threadCount int) *JobSubmitter {
	return &JobSubmitter{
		Context:       ctx,
		UniqueName:    uniqueName,
		JobRunQueue:   azure.InitializeQueue(ctx, storageAccount, storageKey, GetJobRunQueueName(uniqueName)),
		JobStartQueue: azure.InitializeQueue(ctx, storageAccount, storageKey, GetJobStartQueueName(uniqueName)),
		ThreadCount:   threadCount,
		PathManager:   file.InitializeRoundRobinPathManager(mountPaths),
		DirManager:    file.InitializeDirectoryManager(),
	}
}

func (j *JobSubmitter) Run(syncWaitGroup *sync.WaitGroup) {
	log.Info.Printf("[JobSubmitter.Run()\n")
	defer log.Info.Printf("JobSubmitter.Run()]\n")
	defer syncWaitGroup.Done()

	j.Context = SetStatsChannel(j.Context)
	syncWaitGroup.Add(1)
	go StatsCollector(j.Context, syncWaitGroup)

	lastQueueCheckTime := time.Now()
	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	for {
		select {
		case <-j.Context.Done():
			return
		case <-ticker.C:
			if time.Since(lastQueueCheckTime) > timeBetweenQueueCheck {
				lastQueueCheckTime = time.Now()
				dequeue, err := j.JobRunQueue.Dequeue(QueueMessageCount, visibilityTimeout)
				if err != nil {
					log.Error.Printf("error dequeuing %d messages from job run: %v", err)
					continue
				}
				if dequeue.NumMessages() == QueueMessageCount {
					log.Info.Printf("message found, starting workers")
					// delete the message right away, there will be no error recovery for the job worker
					msg := dequeue.Message(0)
					if _, err := j.JobRunQueue.DeleteMessage(msg.ID, msg.PopReceipt); err != nil {
						log.Error.Printf("error deleting queue message from job run queue '%s': %v", msg.ID, err)
					}
					jobRun, err := InitializeJobRunFromString(msg.Text)
					if err != nil {
						log.Error.Printf("error initializing job run from job run queue message '%s': %v", msg.Text, err)
						continue
					}
					j.processJobRun(jobRun)
				} else {
					log.Info.Printf("no message, going back to sleep")
				}
			}
		}
	}
}

func (j *JobSubmitter) processJobRun(jobRun *JobRun) {
	batchName := GenerateBatchNameFromJobRun(j.UniqueName, jobRun.JobRunName, jobRun.BatchID)

	userSyncWaitGroup := sync.WaitGroup{}
	userSyncWaitGroup.Add(j.ThreadCount)

	for i := 0; i < j.ThreadCount; i++ {
		jobCount := jobRun.JobCount / j.ThreadCount
		if i < (jobRun.JobCount % j.ThreadCount) {
			// compensate for uneven job counts not multiples of threadcount
			jobCount++
		}
		go j.JobSubmitterWorkerRun(&userSyncWaitGroup, i, batchName, jobRun, jobCount)
	}

	// wait for the job submitter threads to finish processing the batch
	userSyncWaitGroup.Wait()
	log.Info.Printf("Completed job submission of %d jobs\n", jobRun.JobCount)
}

// JobSubmitterWorkerRun is the entry point for the JobSubmitter go routine
func (j *JobSubmitter) JobSubmitterWorkerRun(syncWaitGroup *sync.WaitGroup, id int, batchName string, jobRun *JobRun, jobCount int) {
	defer syncWaitGroup.Done()
	log.Info.Printf("JobSubmitter %d: starting to submit %d jobs\n", id, jobCount)

	statsChannel := GetStatsChannel(j.Context)

	for i := 0; i < jobCount; i++ {
		// verify not canceled
		if j.isCancelled() {
			log.Info.Printf("JobSubmitter %d saw cancelled", id)
			return
		}

		jobConfigFile := InitializeJobConfigFile(j.getJobName(id, i), jobRun)

		mountPath, folderPath := j.getJobPaths(batchName)

		jobFilePath, err := jobConfigFile.WriteJobConfigFile(JobWriter, folderPath, jobRun.JobFileConfigSizeKB)

		if err != nil {
			log.Error.Printf("error writing job file: %v", err)
			continue
		}

		edaSimFile := &EdasimFile{
			MountPath:   mountPath,
			FullPath:    jobFilePath,
			MountParity: jobRun.MountParity,
		}

		edaSimFileStr, err := edaSimFile.GetEdasimFileString()
		if err != nil {
			log.Error.Printf("error getting the edasimfilestring: %v", err)
			continue
		}

		if err != nil {
			log.Error.Printf("error with GetEdasimFileString: %v", err)
			continue
		}

		// queue completion
		if err := j.JobStartQueue.Enqueue(edaSimFileStr); err != nil {
			log.Error.Printf("error enqueuing message '%s': %v", jobFilePath, err)
			continue
		}
		statsChannel.JobProcessed()
	}

	log.Info.Printf("user %d: completed submitting %d jobs\n", id, jobCount)
}

func (j *JobSubmitter) getJobName(id int, index int) string {
	return fmt.Sprintf("%d_%d", id, index)
}

func (j *JobSubmitter) getJobPaths(batchName string) (string, string) {
	nextMountPoint := j.PathManager.GetNextPath()
	batchPath := path.Join(JobDir, batchName)
	fullPath := path.Join(nextMountPoint, batchPath)
	j.DirManager.EnsureDirectory(fullPath)
	return nextMountPoint, fullPath
}

func (j *JobSubmitter) isCancelled() bool {
	select {
	case <-j.Context.Done():
		return true
	default:
		return false
	}
}
