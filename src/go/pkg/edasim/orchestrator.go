package edasim

import (
	"context"
	"path"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/file"
	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-storage-queue-go/azqueue"
)

const (
	sleepTimeNoWorkers           = time.Duration(10) * time.Millisecond // 10ms
	sleepTimeNoQueueMessages     = time.Duration(10) * time.Second      // 1 second between checking queue
	sleepTimeNoQueueMessagesTick = time.Duration(10) * time.Millisecond // 10 ms between ticks
)

// Orchestrator defines the orchestrator structure
type Orchestrator struct {
	Context             context.Context
	UniqueName          string
	JobStartQueue       *azure.Queue
	WorkStartQueue      *azure.Queue
	WorkComplete        *azure.Queue
	JobComplete         *azure.Queue
	PathManager         *file.RoundRobinPathManager
	DirManager          *file.DirectoryManager
	OrchestratorThreads int
	ReadyCh             chan struct{}
	MsgCh               chan *azqueue.DequeuedMessage
}

// InitializeOrchestrator initializes the Orchestrator
func InitializeOrchestrator(
	ctx context.Context,
	storageAccount string,
	storageKey string,
	uniqueName string,
	mountPaths []string,
	orchestratorThreads int) *Orchestrator {

	return &Orchestrator{
		Context:             ctx,
		JobStartQueue:       azure.InitializeQueue(ctx, storageAccount, storageKey, GetJobStartQueueName(uniqueName)),
		WorkStartQueue:      azure.InitializeQueue(ctx, storageAccount, storageKey, GetWorkStartQueueName(uniqueName)),
		WorkComplete:        azure.InitializeQueue(ctx, storageAccount, storageKey, GetWorkCompleteQueueName(uniqueName)),
		JobComplete:         azure.InitializeQueue(ctx, storageAccount, storageKey, GetJobCompleteQueueName(uniqueName)),
		PathManager:         file.InitializeRoundRobinPathManager(mountPaths),
		DirManager:          file.InitializeDirectoryManager(),
		OrchestratorThreads: orchestratorThreads,
		ReadyCh:             make(chan struct{}),
		MsgCh:               make(chan *azqueue.DequeuedMessage, orchestratorThreads),
	}
}

// Run implements the go routine entry point for the orchestrator.  This starts the various go routines for managment of the queues
func (o *Orchestrator) Run(syncWaitGroup *sync.WaitGroup) {
	log.Info.Printf("started orchestrator.Run()\n")
	defer syncWaitGroup.Done()

	// start the stats collector
	o.Context = SetStatsChannel(o.Context)
	syncWaitGroup.Add(1)
	go StatsCollector(o.Context, syncWaitGroup)

	// start the ready queue listener and its workers
	// this uses the example from here: https://github.com/Azure/azure-storage-queue-go/blob/master/azqueue/zt_examples_test.go
	log.Info.Printf("started %d orchestrator threads", o.OrchestratorThreads)
	for i := 0; i < o.OrchestratorThreads; i++ {
		syncWaitGroup.Add(1)
		go o.StartJobWorker(syncWaitGroup)
	}

	// start the job dispatcher to submit jobs to works
	syncWaitGroup.Add(1)
	go o.JobDispatcher(syncWaitGroup)

	// start the completed queue listener
	// not yet implemented

	for {
		select {
		case <-o.Context.Done():
			log.Info.Printf("completed orchestrator.Run()\n")
			return
		}
	}
}

// StartJobWorker implements the go routine of the worker that gets jobs from the queue
func (o *Orchestrator) StartJobWorker(syncWaitGroup *sync.WaitGroup) {
	defer syncWaitGroup.Done()
	log.Info.Printf("[StartJobWorker")
	defer log.Info.Printf("completed StartJobWorker]")

	statsChannel := GetStatsChannel(o.Context)

	for {
		// signal that the work is ready to receive work
		select {
		case <-o.Context.Done():
			return
		case o.ReadyCh <- struct{}{}:
		}
		// handle the messages
		select {
		case <-o.Context.Done():
			return
		case msg := <-o.MsgCh:
			if err := o.handleMessage(msg); err != nil {
				statsChannel.Error()
			} else {
				statsChannel.ProcessedFilesWritten()
			}
		}
	}
}

// JobDispatcher dispatches jobs to workers based on input from the ready queue
func (o *Orchestrator) JobDispatcher(syncWaitGroup *sync.WaitGroup) {
	log.Debug.Printf("[JobDispatcher\n")
	defer syncWaitGroup.Done()
	defer log.Debug.Printf("JobDispatcher]")

	readyWorkerCount := int32(0)

	statsChannel := GetStatsChannel(o.Context)

	for {
		done := false
		for !done {
			select {
			case <-o.Context.Done():
				return
			case <-o.ReadyCh:
				readyWorkerCount++
			default:
				done = true
			}
		}
		if readyWorkerCount == 0 {
			// no workers, wait 1ms
			time.Sleep(sleepTimeNoWorkers)
			continue
		}

		// dequeue the messages, with no more than ready workers
		dequeue, err := o.JobStartQueue.Dequeue(readyWorkerCount, visibilityTimeout)
		if err != nil {
			log.Error.Printf("error dequeuing %d messages from ready queue: %v", readyWorkerCount, err)
			statsChannel.Error()
			continue
		}

		if dequeue.NumMessages() != 0 {
			now := time.Now()
			for m := int32(0); m < dequeue.NumMessages(); m++ {
				msg := dequeue.Message(m)
				if now.After(msg.NextVisibleTime) {
					log.Error.Printf("%v is after, ignoring", msg)
					continue
				}
				o.MsgCh <- msg
				statsChannel.JobProcessed()
				readyWorkerCount--
			}
		} else {
			// otherwise sleep 10 seconds
			log.Info.Printf("Dispatcher: no messages, sleeping, %d ready workers", readyWorkerCount)
			ticker := time.NewTicker(sleepTimeNoQueueMessagesTick)
			start := time.Now()
			for time.Since(start) < sleepTimeNoQueueMessages {
				select {
				case <-o.Context.Done():
					return
				case <-ticker.C:
				}
			}
			ticker.Stop()
			log.Info.Printf("Dispatcher: awake")
		}
	}
}

func (o *Orchestrator) handleMessage(msg *azqueue.DequeuedMessage) error {
	edasimFile, err := InitializeEdasimFileFromString(msg.Text)
	if err != nil {
		log.Error.Printf("error reading edasim file from '%s': %v", msg.Text, err)
		return err
	}
	log.Debug.Printf("[handleMessage(%s)", edasimFile.FullPath)
	defer log.Debug.Printf("handleMessage(%s)]", edasimFile.FullPath)

	configFilename := o.getConfigFilename(edasimFile)

	jobConfig, err := ReadJobConfigFile(JobReader, configFilename)
	if err != nil {
		log.Error.Printf("error reading job file '%s': %v", configFilename, err)
		return err
	}

	batchName := GetBatchName(configFilename)
	mountPath, fullPath := o.getWorkPaths(batchName)

	workerFileWriter := InitializeWorkerFileWriter(
		jobConfig.Name,
		&jobConfig.JobRun)
	if err := workerFileWriter.WriteStartFiles(WorkStartFileWriter, fullPath, jobConfig.JobRun.WorkStartFileSizeKB, jobConfig.JobRun.WorkStartFileCount); err != nil {
		log.Error.Printf("error writing start files for job '%s': %v", configFilename, err)
		return err
	}

	edaSimFile := &EdasimFile{
		MountPath:   mountPath,
		FullPath:    fullPath,
		MountParity: jobConfig.JobRun.MountParity,
	}

	edaSimFileStr, err := edaSimFile.GetEdasimFileString()
	if err != nil {
		log.Error.Printf("error getting the edasimfilestring: %v", err)
		return err
	}

	if err := o.WorkStartQueue.Enqueue(edaSimFileStr); err != nil {
		log.Error.Printf("error enqueuing files path '%s': %v", workerFileWriter.FirstStartFile(fullPath), err)
		return err
	}
	if _, err := o.JobStartQueue.DeleteMessage(msg.ID, msg.PopReceipt); err != nil {
		log.Error.Printf("error deleting queue message from ready queue '%s': %v", msg.ID, err)
		return err
	}
	return nil
}

func (o *Orchestrator) getConfigFilename(edasimFile *EdasimFile) string {
	if edasimFile.MountParity == true {
		return edasimFile.FullPath
	} else {
		filePath := edasimFile.FullPath[len(edasimFile.MountPath):]
		return path.Join(o.PathManager.GetNextPath(), filePath)
	}
}

func (o *Orchestrator) getWorkPaths(batchName string) (string, string) {
	nextMountPoint := o.PathManager.GetNextPath()
	batchPath := path.Join(WorkDir, batchName)
	fullPath := path.Join(nextMountPoint, batchPath)
	o.DirManager.EnsureDirectory(fullPath)
	return nextMountPoint, fullPath
}
