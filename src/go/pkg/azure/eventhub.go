package azure

import (
	"container/list"
	"context"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-amqp-common-go/sas"
	eventhubs "github.com/Azure/azure-event-hubs-go"
)

const (
	sleepTimeNoEvents = time.Duration(10) * time.Millisecond // 10ms
	maxBatchBytes     = 128 * 1024                           // to allow for overhead, we will go half the 256 KB limit https://docs.microsoft.com/en-us/Azure/event-hubs/event-hubs-programming-guide
)

// EventHubSender sends messages to Azure Event Hub
type EventHubSender struct {
	ctx            context.Context
	hub            *eventhubs.Hub
	queue          *list.List
	mux            sync.Mutex
	senderComplete bool
}

// InitializeEventHubSender initializes an event hub sender
func InitializeEventHubSender(
	ctx context.Context,
	senderKeyName string,
	senderKey string,
	eventHubNamespaceName string,
	eventHubName string) (*EventHubSender, error) {

	provider, err := sas.NewTokenProvider(sas.TokenProviderWithKey(senderKeyName, senderKey))
	if err != nil {
		return nil, err
	}

	hub, err := eventhubs.NewHub(eventHubNamespaceName, eventHubName, provider)
	if err != nil {
		return nil, err
	}

	e := &EventHubSender{
		ctx:            ctx,
		hub:            hub,
		queue:          list.New(),
		senderComplete: false,
	}

	go e.sender()

	return e, nil
}

// RecordTiming implements interface Profiler
func (e *EventHubSender) RecordTiming(bytes []byte) {
	e.mux.Lock()
	defer e.mux.Unlock()
	e.queue.PushBack(bytes)
}

func (e *EventHubSender) IsSenderComplete() bool {
	return e.senderComplete
}

func (e *EventHubSender) eventsExist() bool {
	e.mux.Lock()
	defer e.mux.Unlock()
	return e.queue.Len() > 0
}

func (e *EventHubSender) sendEventsBatch() {
	e.mux.Lock()

	if e.queue.Len() == 0 {
		e.mux.Unlock()
		return
	}

	// build up the batch in the context of the lock
	eventHubBatchSize := 0
	events := make([]*eventhubs.Event, 0, e.queue.Len())
	for e.queue.Len() > 0 {
		qItem := e.queue.Front()
		newLength := eventHubBatchSize + len(qItem.Value.([]byte))
		if newLength < maxBatchBytes {
			eventHubBatchSize = newLength
			events = append(events, eventhubs.NewEvent(e.queue.Remove(qItem).([]byte)))
		} else {
			break
		}
	}
	e.mux.Unlock()

	err := e.hub.SendBatch(e.ctx, eventhubs.NewEventBatch(events))
	if err != nil {
		log.Error.Printf("failed to send batch: %v\n", err)
	}
}

func (e *EventHubSender) sender() {
	log.Info.Printf("starting EventHubSender sender\n")
	defer func(e *EventHubSender) { e.senderComplete = true }(e)
	defer log.Info.Printf("completed EventHubSender sender")
	for {
		select {
		case <-e.ctx.Done():
			return
		default:
			time.Sleep(sleepTimeNoEvents)
		}
		if e.eventsExist() {
			e.sendEventsBatch()
		} else {
			time.Sleep(sleepTimeNoEvents)
		}
	}
}
