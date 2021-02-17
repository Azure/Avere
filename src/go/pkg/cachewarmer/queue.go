// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"context"
	"fmt"

	"github.com/Azure/Avere/src/go/pkg/azure"
)

type CacheWarmerQueues struct {
	jobQueue  *azure.Queue
	workQueue *azure.Queue
}

func InitializeCacheWarmerQueues(
	ctx context.Context,
	storageAccount string,
	storageKey string,
	queueNamePrefix string) (*CacheWarmerQueues, error) {

	jobQueue, err := azure.InitializeQueueNonFatal(ctx, storageAccount, storageKey, fmt.Sprintf("%s%s", queueNamePrefix, WarmPathJobQueueSuffix))
	if err != nil {
		return nil, err
	}
	workQueue, err := azure.InitializeQueueNonFatal(ctx, storageAccount, storageKey, fmt.Sprintf("%s%s", queueNamePrefix, WorkQueueSuffix))
	if err != nil {
		return nil, err
	}

	return &CacheWarmerQueues{
		jobQueue:  jobQueue,
		workQueue: workQueue,
	}, nil
}

func (q *CacheWarmerQueues) WriteWarmPathJob(job WarmPathJob) error {
	content, err := job.GetWarmPathJobFileContents()
	if err != nil {
		return err
	}

	if err := q.jobQueue.Enqueue(content); err != nil {
		return fmt.Errorf("Error writing job: %v", err)
	}

	return nil
}

// IsJobQueueEmpty returns true if there are one or more visible or invisible items in the queue
func (q *CacheWarmerQueues) IsJobQueueEmpty() (bool, error) {
	if isEmpty, err := q.jobQueue.IsQueueEmpty(); err != nil {
		return false, fmt.Errorf("error checking if job queue was empty: %v", err)
	} else {
		return isEmpty, nil
	}
}

func (q *CacheWarmerQueues) GetWarmPathJob() (*WarmPathJob, error) {
	queueMessage, err := q.jobQueue.Dequeue(NumberOfMessagesToDequeue, CacheWarmerVisibilityTimeout)
	if err != nil {
		return nil, fmt.Errorf("error dequeueing message %v", err)
	}
	if queueMessage.NumMessages() == NumberOfMessagesToDequeue {
		msg := queueMessage.Message(0)
		warmPathJob, err := InitializeWarmPathJobFromString(msg.Text)
		if err != nil {
			return nil, fmt.Errorf("error parsing message text '%s': '%v'", msg.Text, err)
		}
		warmPathJob.SetQueueMessageInfo(&(msg.ID), &(msg.PopReceipt))
		return warmPathJob, nil
	}
	return nil, nil
}

func (q *CacheWarmerQueues) StillProcessingWarmPathJob(warmPathJob *WarmPathJob) error {
	id, popReceipt := warmPathJob.GetQueueMessageInfo()
	if id == nil || popReceipt == nil {
		return fmt.Errorf("queue message id incorrectly set for warmpathjob")
	}
	message, err := warmPathJob.GetWarmPathJobFileContents()
	if err != nil {
		return err
	}
	if _, err := q.jobQueue.UpdateVisibilityTimeout(*id, *popReceipt, CacheWarmerVisibilityTimeout, message); err != nil {
		return err
	}
	return nil
}

func (q *CacheWarmerQueues) DeleteWarmPathJob(warmPathJob *WarmPathJob) error {
	id, popReceipt := warmPathJob.GetQueueMessageInfo()
	if id == nil || popReceipt == nil {
		return fmt.Errorf("queue message id incorrectly set for warmpathjob")
	}
	if _, err := q.jobQueue.DeleteMessage(*id, *popReceipt); err != nil {
		return err
	}
	return nil
}

func (q *CacheWarmerQueues) IsWorkQueueEmpty() (bool, error) {
	if isEmpty, err := q.workQueue.IsQueueEmpty(); err != nil {
		return false, fmt.Errorf("error checking if work queue was empty: %v", err)
	} else {
		return isEmpty, nil
	}
}

func (q *CacheWarmerQueues) WriteWorkerJob(workerjob *WorkerJob) error {
	content, err := workerjob.GetWorkerJobFileContents()
	if err != nil {
		return err
	}

	if err := q.workQueue.Enqueue(content); err != nil {
		return fmt.Errorf("Error writing job: %v", err)
	}

	return nil
}

func (q *CacheWarmerQueues) PeekWorkerJob() (*WorkerJob, error) {
	peekMessage, err := q.workQueue.Peek(NumberOfMessagesToDequeue)
	if err != nil {
		return nil, fmt.Errorf("error dequeueing message %v", err)
	}
	if peekMessage.NumMessages() == NumberOfMessagesToDequeue {
		msg := peekMessage.Message(0)
		workerJob, err := InitializeWorkerJobFromString(msg.Text)
		if err != nil {
			return nil, fmt.Errorf("error parsing message text '%s': '%v'", msg.Text, err)
		}
		workerJob.SetQueueMessageInfo(&(msg.ID), nil)
		return workerJob, nil
	}
	return nil, nil
}

func (q *CacheWarmerQueues) GetWorkerJob() (*WorkerJob, error) {
	queueMessage, err := q.workQueue.Dequeue(NumberOfMessagesToDequeue, CacheWarmerVisibilityTimeout)
	if err != nil {
		return nil, fmt.Errorf("error dequeueing message %v", err)
	}
	if queueMessage.NumMessages() == NumberOfMessagesToDequeue {
		msg := queueMessage.Message(0)
		workerJob, err := InitializeWorkerJobFromString(msg.Text)
		if err != nil {
			return nil, fmt.Errorf("error parsing message text '%s': '%v'", msg.Text, err)
		}
		workerJob.SetQueueMessageInfo(&(msg.ID), &(msg.PopReceipt))
		return workerJob, nil
	}
	return nil, nil
}

func (q *CacheWarmerQueues) StillProcessingWorkerJob(workerJob *WorkerJob) error {
	id, popReceipt := workerJob.GetQueueMessageInfo()
	if id == nil || popReceipt == nil {
		return fmt.Errorf("queue message id incorrectly set for workerjob")
	}
	message, err := workerJob.GetWorkerJobFileContents()
	if err != nil {
		return err
	}
	if _, err := q.workQueue.UpdateVisibilityTimeout(*id, *popReceipt, CacheWarmerVisibilityTimeout, message); err != nil {
		return err
	}
	return nil
}

func (q *CacheWarmerQueues) DeleteWorkerJob(workerJob *WorkerJob) error {
	id, popReceipt := workerJob.GetQueueMessageInfo()
	if id == nil || popReceipt == nil {
		return fmt.Errorf("queue message id incorrectly set for workerjob")
	}
	if _, err := q.workQueue.DeleteMessage(*id, *popReceipt); err != nil {
		return err
	}
	return nil
}
