// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package azure

import (
	"container/list"
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-amqp-common-go/v3/sas"
	eventhubs "github.com/Azure/azure-event-hubs-go/v3"
)

const (
	sleepTimeNoEvents        = time.Duration(10) * time.Millisecond // 10ms
	maxBatchBytes            = 128 * 1024                           // to allow for overhead, we will go half the 256 KB limit https://docs.microsoft.com/en-us/Azure/event-hubs/event-hubs-programming-guide
	connectionStringTemplate = "Endpoint=sb://%s.servicebus.windows.net/;SharedAccessKeyName=%s;SharedAccessKey=%s"
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

	if err := createHubIfNotExists(ctx, senderKeyName, senderKey, eventHubNamespaceName, eventHubName); err != nil {
		log.Debug.Printf("createHubIfNotExists error: %v", err)
		return nil, err
	}

	provider, err := sas.NewTokenProvider(sas.TokenProviderWithKey(senderKeyName, senderKey))
	if err != nil {
		log.Debug.Printf("NewTokenProvider error: %v", err)
		return nil, err
	}

	hub, err := eventhubs.NewHub(eventHubNamespaceName, eventHubName, provider)
	if err != nil {
		log.Debug.Printf("NewHub error: %v", err)
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

	err := e.hub.SendBatch(e.ctx, eventhubs.NewEventBatchIterator(events...))
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

func createHubIfNotExists(ctx context.Context, eventHubSenderName, eventHubSenderKey, eventHubNamespaceName, eventHubName string) error {
	log.Info.Printf("[createHubIfNotExists(%s, %s),", eventHubNamespaceName, eventHubName)
	defer log.Info.Printf("createHubIfNotExists]")
	connectionString := createHubConnectionString(eventHubSenderName, eventHubSenderKey, eventHubNamespaceName)
	hubmanager, err := eventhubs.NewHubManagerFromConnectionString(connectionString)
	if err != nil {
		log.Debug.Printf("NewHubManagerFromConnectionString error: %v", hubmanager)
		return err
	}

	if _, err = hubmanager.Put(ctx, eventHubName); err == nil {
		log.Info.Printf("created event hub %s", eventHubName)
	} else {
		if strings.Contains(err.Error(), "409") {
			log.Debug.Printf("the event hub %s already exists", eventHubName)
		} else {
			return err
		}
	}

	return nil
}

func createHubConnectionString(eventHubSenderName, eventHubSenderKey, eventHubNamespaceName string) string {
	return fmt.Sprintf(connectionStringTemplate, eventHubNamespaceName, eventHubSenderName, eventHubSenderKey)
}
