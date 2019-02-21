// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package azure

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"regexp"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-storage-queue-go/azqueue"
)

const (
	enqueueVisibilityTimeout   = time.Duration(0) * time.Second  // make the message available immediately
	enqueueMessageTTL          = time.Duration(-1) * time.Second // never expire
	productionQueueURLTemplate = "https://%s.queue.core.windows.net"
)

// Queue represents a single azure storage queue
// The implementation has been influenced by https://github.com/Azure/azure-storage-queue-go/blob/master/azqueue/zt_examples_test.go
type Queue struct {
	MessagesURL azqueue.MessagesURL
	Context     context.Context
}

// FatalValidateQueue exits the program if the queuename is not valid
func FatalValidateQueueName(queueName string) {
	isValid, errorMessage := ValidateQueueName(queueName)
	if !isValid {
		log.Error.Printf(errorMessage)
		os.Exit(1)
	}
}

// ValidateQueue validates queue name according to https://docs.microsoft.com/en-us/rest/api/storageservices/naming-queues-and-metadata
func ValidateQueueName(queueName string) (bool, string) {
	matched, err := regexp.MatchString("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", queueName)

	if err != nil {
		errorMessage := fmt.Sprintf("error while parsing queue Name '%s' to server: %v", queueName, err)
		return false, errorMessage
	}

	if !matched {
		errorMessage := fmt.Sprintf("'%s' is not a valid queue name.  Queue needs to be 3-63 lowercase alphanumeric characters where all but the first and last character may be dash (https://docs.microsoft.com/en-us/rest/api/storageservices/naming-queues-and-metadata)", queueName)
		return false, errorMessage
	}
	return true, ""
}

// InitializeQueue creates a Queue to represent the Azure Storage Queue
func InitializeQueue(ctx context.Context, storageAccount string, storageAccountKey string, queueName string) *Queue {

	credential, err := azqueue.NewSharedKeyCredential(storageAccount, storageAccountKey)

	if err != nil {
		log.Error.Printf("unable to get the credentials: %v", err)
		panic(err)
	}

	p := azqueue.NewPipeline(credential, azqueue.PipelineOptions{})

	u, _ := url.Parse(fmt.Sprintf(productionQueueURLTemplate, storageAccount))

	serviceURL := azqueue.NewServiceURL(*u, p)

	// Create a URL that references the queue in the Azure Storage account.
	queueURL := serviceURL.NewQueueURL(queueName) // Queue names require lowercase

	// create the queue if it does not already exist
	if queueCreateResponse, err := queueURL.Create(ctx, azqueue.Metadata{}); err != nil {
		if serr, ok := err.(azqueue.StorageError); !ok || serr.ServiceCode() != azqueue.ServiceCodeQueueAlreadyExists {
			log.Error.Printf("error encountered: %v", serr.ServiceCode())
		}
	} else if queueCreateResponse.StatusCode() == 201 {
		log.Info.Printf("successfully created queue '%s'", queueName)
	}

	messagesURL := queueURL.NewMessagesURL()

	return &Queue{
		MessagesURL: messagesURL,
		Context:     ctx,
	}
}

// Enqueue enqueues the message to the queue
func (q *Queue) Enqueue(message string) error {
	_, err := q.MessagesURL.Enqueue(q.Context, message, enqueueVisibilityTimeout, enqueueMessageTTL)
	return err
}

// Dequeue marks the item in the storage invisible, but the message will re-appear until deleted
func (q *Queue) Dequeue(maxMessages int32, visibilityTimeout time.Duration) (*azqueue.DequeuedMessagesResponse, error) {
	return q.MessagesURL.Dequeue(q.Context, maxMessages, visibilityTimeout)
}

// DeleteMessage deletes the message from the queue
func (q *Queue) DeleteMessage(messageID azqueue.MessageID, popReceipt azqueue.PopReceipt) (*azqueue.MessageIDDeleteResponse, error) {
	msgIDURL := q.MessagesURL.NewMessageIDURL(messageID)
	return msgIDURL.Delete(q.Context, popReceipt)
}
