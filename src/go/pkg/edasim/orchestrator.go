package edasim

import (
	"context"
	"path"
	"sync"
	"time"

	"github.com/Azure/azure-storage-queue-go/2017-07-29/azqueue"
	"github.com/azure/avere/src/go/pkg/azure"
	"github.com/azure/avere/src/go/pkg/file"
	"github.com/azure/avere/src/go/pkg/log"
)

const (
	sleepTimeNoWorkers           = time.Duration(10) * time.Millisecond // 10ms
	sleepTimeNoQueueMessages     = time.Duration(10) * time.Second      // 1 second between checking queue
	sleepTimeNoQueueMessagesTick = time.Duration(10) * time.Millisecond // 10 ms between ticks
	visibilityTimeout            = time.Duration(300) * time.Second     // 5 minute visibility timeout
)

// Orchestrator defines the orchestrator structure
type Orchestrator struct {
	Context                     context.Context
	ReadyQueue                  *azure.Queue
	ProcessQueue                *azure.Queue
	CompleteQueue               *azure.Queue
	UploaderQueue               *azure.Queue
	JobFileSizeKB               int
	JobStartFileCount           int
	JobProcessFilesPath         string
	JobCompleteFileSizeKB       int
	JobCompleteFailedFileSizeKB int
	JobFailedProbability        float64
	JobCompleteFileCount        int
	OrchestratorThreads         int
	ReadyCh                     chan struct{}
	MsgCh                       chan *azqueue.DequeuedMessage
	DirManager                  *file.DirectoryManager
}

// InitializeOrchestrator initializes the Orchestrator
func InitializeOrchestrator(
	ctx context.Context,
	storageAccount string,
	storageAccountKey string,
	readyQueueName string,
	processQueueName string,
	completedQueueName string,
	uploaderQueueName string,
	jobFileSizeKB int,
	jobStartFileCount int,
	jobProcessFilesPath string,
	jobCompleteFileSizeKB int,
	jobCompleteFailedFileSizeKB int,
	jobFailedProbability float64,
	jobCompleteFileCount int,
	orchestratorThreads int) *Orchestrator {

	return &Orchestrator{
		Context:                     ctx,
		ReadyQueue:                  azure.InitializeQueue(ctx, storageAccount, storageAccountKey, readyQueueName),
		ProcessQueue:                azure.InitializeQueue(ctx, storageAccount, storageAccountKey, processQueueName),
		CompleteQueue:               azure.InitializeQueue(ctx, storageAccount, storageAccountKey, completedQueueName),
		UploaderQueue:               azure.InitializeQueue(ctx, storageAccount, storageAccountKey, uploaderQueueName),
		JobFileSizeKB:               jobFileSizeKB,
		JobStartFileCount:           jobStartFileCount,
		JobProcessFilesPath:         jobProcessFilesPath,
		JobCompleteFileSizeKB:       jobCompleteFileSizeKB,
		JobCompleteFailedFileSizeKB: jobCompleteFailedFileSizeKB,
		JobFailedProbability:        jobFailedProbability,
		JobCompleteFileCount:        jobCompleteFileCount,
		OrchestratorThreads:         orchestratorThreads,
		ReadyCh:                     make(chan struct{}),
		MsgCh:                       make(chan *azqueue.DequeuedMessage, orchestratorThreads),
		DirManager:                  file.InitializeDirectoryManager(),
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
	// this uses the example from here: https://github.com/Azure/azure-storage-queue-go/blob/master/2017-07-29/azqueue/zt_examples_test.go
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
	log.Info.Printf("[JobDispatcher\n")
	defer syncWaitGroup.Done()
	defer log.Info.Printf("JobDispatcher]")

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
		dequeue, err := o.ReadyQueue.Dequeue(readyWorkerCount, visibilityTimeout)
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
	log.Debug.Printf("[handleMessage(%s)", msg.Text)
	defer log.Debug.Printf("handleMessage(%s)]", msg.Text)
	configFilename := msg.Text
	batchName := GetBatchName(msg.Text)

	jobConfig, err := ReadJobConfigFile(JobReader, configFilename)
	if err != nil {
		log.Error.Printf("error reading job file '%s': %v", configFilename, err)
		return err
	}

	fullPath := o.getDirectory(batchName)

	workerFileWriter := InitializeWorkerFileWriter(
		jobConfig.Name,
		o.JobFileSizeKB,
		o.JobStartFileCount,
		o.JobCompleteFileSizeKB,
		o.JobCompleteFileCount,
		o.JobCompleteFailedFileSizeKB,
		o.JobFailedProbability)
	if err := workerFileWriter.WriteStartFiles(WorkStartFileWriter, fullPath, o.JobFileSizeKB); err != nil {
		log.Error.Printf("error writing start files for job '%s': %v", configFilename, err)
		return err
	}

	if err := o.ProcessQueue.Enqueue(workerFileWriter.FirstStartFile(fullPath)); err != nil {
		log.Error.Printf("error enqueuing files path '%s': %v", workerFileWriter.FirstStartFile(fullPath), err)
		return err
	}
	if _, err := o.ReadyQueue.DeleteMessage(msg.ID, msg.PopReceipt); err != nil {
		log.Error.Printf("error deleting queue message from ready queue '%s': %v", msg.ID, err)
		return err
	}
	return nil
}

func (o *Orchestrator) getDirectory(batchName string) string {
	fullPath := path.Join(o.JobProcessFilesPath, batchName)
	o.DirManager.EnsureDirectory(fullPath)
	return fullPath
}
