// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"context"
	"flag"
	"fmt"
	l "log"
	"os"
	"strings"
	"time"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/cli"
	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-event-hubs-go/v3/persist"
	"github.com/Azure/azure-amqp-common-go/v3/sas"
	eventhubs "github.com/Azure/azure-event-hubs-go/v3"
)

const (
	millisecondsSleep        = 10
	quitAfterInactiveSeconds = time.Duration(1) * time.Second
	statsPrintRate           = time.Duration(5) * time.Second
	AZURE_EVENTHUB_HUBNAME   = "AZURE_EVENTHUB_HUBNAME"
)

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "error: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       write the job config file and posts to the queue\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "required env vars:\n")
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub sender name\n", azure.AZURE_EVENTHUB_SENDERKEYNAME)
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub sender key\n", azure.AZURE_EVENTHUB_SENDERKEY)
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub namespace name\n", azure.AZURE_EVENTHUB_NAMESPACENAME)
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub name\n", AZURE_EVENTHUB_HUBNAME)
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func verifyEnvVars() bool {
	available := true
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_SENDERKEYNAME)
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_SENDERKEY)
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_NAMESPACENAME)
	available = available && cli.VerifyEnvVar(AZURE_EVENTHUB_HUBNAME)
	return available
}

func testEventHub() {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")

	flag.Parse()

	if *enableDebugging {
		log.EnableDebugging()
	}

	if envVarsAvailable := verifyEnvVars(); !envVarsAvailable {
		usage()
		os.Exit(1)
	}

	eventHubSenderName := cli.GetEnv(azure.AZURE_EVENTHUB_SENDERKEYNAME)
	eventHubSenderKey := cli.GetEnv(azure.AZURE_EVENTHUB_SENDERKEY)
	eventHubNamespaceName := cli.GetEnv(azure.AZURE_EVENTHUB_NAMESPACENAME)
	eventHubHubName := cli.GetEnv(AZURE_EVENTHUB_HUBNAME)

	// create the new event Hub name
	log.Info.Printf("new event hub manager")
	connectionString := createHubConnectionString(eventHubSenderName, eventHubSenderKey, eventHubNamespaceName)
	hubmanager, err := eventhubs.NewHubManagerFromConnectionString(connectionString)
	if err != nil {
		panic(err)
	}

	log.Info.Printf("new event hub %s", eventHubHubName)
	if _, err = hubmanager.Put(context.Background(), eventHubHubName); err == nil {
		log.Info.Printf("created event hub %s", eventHubHubName)
	} else {
		if strings.Contains(err.Error(), "409") {
			log.Info.Printf("the event hub %s already exists", eventHubHubName)
		} else {
			panic(err)
		}
	}

	log.Info.Printf("new token provider")
	provider, err := sas.NewTokenProvider(sas.TokenProviderWithKey(eventHubSenderName, eventHubSenderKey))
	if err != nil {
		panic(err)
	}

	log.Info.Printf("new hub %s, %s", eventHubNamespaceName, eventHubHubName)
	hub, err := eventhubs.NewHub(eventHubNamespaceName, eventHubHubName, provider)
	if err != nil {
		panic(err)
	}

	log.Info.Printf("put a new event")
	event := eventhubs.NewEvent([]byte(fmt.Sprintf("hello world %v", time.Now())))
	if err := hub.Send(context.Background(), event); err != nil {
		panic(err)
	}

	// set up wait group to wait for expected message
	eventReceived := make(chan struct{})

	// declare handler for incoming events
	handler := func(ctx context.Context, event *eventhubs.Event) error {
		log.Info.Printf("received: %s\n", string(event.Data))
		// notify channel that event was received
		eventReceived <- struct{}{}
		return nil
	}

	info, err := hub.GetRuntimeInformation(context.Background())
	if err != nil {
		panic(err)
	}

	var receiveOption eventhubs.ReceiveOption
	receiveOption = eventhubs.ReceiveWithStartingOffset(persist.StartOfStream)

	for _, partitionID := range info.PartitionIDs {
		_, err := hub.Receive(
			context.Background(),
			partitionID,
			handler,
			receiveOption,
		)
		if err != nil {
			l.Fatalf("failed to receive for partition ID %s: %s\n", partitionID, err)
		}
	}

	lastEventReceived := time.Now()
	lastStatsOutput := time.Now()
	ticker := time.NewTicker(time.Duration(10) * time.Millisecond)
	defer ticker.Stop()
	for time.Since(lastEventReceived) <= quitAfterInactiveSeconds {
		select {
		case <-eventReceived:
			lastEventReceived = time.Now()
		case <-ticker.C:
			if time.Since(lastStatsOutput) > statsPrintRate {
				lastStatsOutput = time.Now()
				log.Info.Printf("still receiving events")
			}
		}
	}
}

func createHubConnectionString(eventHubSenderName, eventHubSenderKey, eventHubNamespaceName string) string {
	return fmt.Sprintf("Endpoint=sb://%s.servicebus.windows.net/;SharedAccessKeyName=%s;SharedAccessKey=%s", eventHubNamespaceName, eventHubSenderName, eventHubSenderKey)
}

func main() {

	testEventHub()
}
