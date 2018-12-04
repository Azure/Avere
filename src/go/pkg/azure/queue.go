package azure

import (
	"context"
	"fmt"
	"net/url"
	"time"

	"github.com/Azure/azure-storage-queue-go/2017-07-29/azqueue"
)

const (
	enqueueVisibilityTimeout   = time.Duration(0) * time.Second  // make the message available immediately
	enqueueMessageTTL          = time.Duration(-1) * time.Second // never expire
	productionQueueURLTemplate = "https://%s.queue.core.windows.net"
)

// Queue represents a single azure storage queue
// The implementation has been influenced by https://github.com/Azure/azure-storage-queue-go/blob/master/2017-07-29/azqueue/zt_examples_test.go
type Queue struct {
	MessagesURL azqueue.MessagesURL
	Context     context.Context
}

// InitializeQueue creates a Queue to represent the Azure Storage Queue
func InitializeQueue(ctx context.Context, storageAccount string, storageAccountKey string, queueName string) *Queue {

	credential := azqueue.NewSharedKeyCredential(storageAccount, storageAccountKey)

	p := azqueue.NewPipeline(credential, azqueue.PipelineOptions{})

	u, _ := url.Parse(fmt.Sprintf(productionQueueURLTemplate, storageAccount))

	serviceURL := azqueue.NewServiceURL(*u, p)

	// Create a URL that references the queue in the Azure Storage account.
	queueURL := serviceURL.NewQueueURL(queueName) // Queue names require lowercase

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
