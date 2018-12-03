package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/Azure/azure-amqp-common-go/persist"
	"github.com/Azure/azure-amqp-common-go/sas"
	eventhubs "github.com/Azure/azure-event-hubs-go"
	"github.com/azure/avere/src/go/pkg/azure"
	"github.com/azure/avere/src/go/pkg/cli"
	"github.com/azure/avere/src/go/pkg/file"
)

const (
	millisecondsSleep        = 10
	quitAfterInactiveSeconds = time.Duration(5) * time.Second
	statsPrintRate           = time.Duration(5) * time.Second
)

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "error: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "usage: %s\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       write the job config file and posts to the queue\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "required env vars:\n")
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub sender name\n", azure.AZURE_EVENTHUB_SENDERKEYNAME)
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub sender key\n", azure.AZURE_EVENTHUB_SENDERKEY)
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub namespace name\n", azure.AZURE_EVENTHUB_NAMESPACENAME)
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub hub name\n", azure.AZURE_EVENTHUB_HUBNAME)
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func verifyEnvVars() bool {
	available := true
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_SENDERKEYNAME)
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_SENDERKEY)
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_NAMESPACENAME)
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_HUBNAME)
	return available
}

func getEnv(envVarName string) string {
	s := os.Getenv(envVarName)

	if len(s) > 0 && s[0] == '"' {
		s = s[1:]
	}

	if len(s) > 0 && s[len(s)-1] == '"' {
		s = s[:len(s)-1]
	}

	return s
}

func initializeApplicationVariables() (string, string, string, string, string) {
	var statsFilePath = flag.String("statsFilePath", "", "the stats file path")
	flag.Parse()

	if envVarsAvailable := verifyEnvVars(); !envVarsAvailable {
		usage()
		os.Exit(1)
	}

	eventHubSenderName := cli.GetEnv(azure.AZURE_EVENTHUB_SENDERKEYNAME)
	eventHubSenderKey := cli.GetEnv(azure.AZURE_EVENTHUB_SENDERKEY)
	eventHubNamespaceName := cli.GetEnv(azure.AZURE_EVENTHUB_NAMESPACENAME)
	eventHubHubName := cli.GetEnv(azure.AZURE_EVENTHUB_HUBNAME)

	if len(*statsFilePath) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: statsFilePath is not specified\n")
		usage()
		os.Exit(1)
	}

	if _, err := os.Stat(*statsFilePath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "ERROR: statsFilePath '%s' does not exist\n", *statsFilePath)
		usage()
		os.Exit(1)
	}

	return *statsFilePath, eventHubSenderName, eventHubSenderKey, eventHubNamespaceName, eventHubHubName
}

func main() {
	statsFilePath, eventHubSenderName, eventHubSenderKey, eventHubNamespaceName, eventHubHubName := initializeApplicationVariables()

	log.Printf("Eventhub Details:\n")
	log.Printf("\teventHubSenderName: %s\n", eventHubSenderName)
	log.Printf("\teventHubSenderKey: %s\n", eventHubSenderKey)
	log.Printf("\teventHubNamespaceName: %s\n", eventHubNamespaceName)
	log.Printf("\teventHubHubName: %s\n", eventHubHubName)

	ioStatsCollector := file.InitializeIOStatsCollector()

	provider, err := sas.NewTokenProvider(sas.TokenProviderWithKey(eventHubSenderName, eventHubSenderKey))
	if err != nil {
		log.Fatalf("failed to get token provider: %s\n", err)
	}

	// get an existing hub
	hub, err := eventhubs.NewHub(eventHubNamespaceName, eventHubHubName, provider)
	ctx := context.Background()
	defer hub.Close(ctx)
	if err != nil {
		log.Fatalf("failed to get hub: %s\n", err)
	}

	// get info about partitions in hub
	info, err := hub.GetRuntimeInformation(ctx)
	if err != nil {
		log.Fatalf("failed to get runtime info: %s\n", err)
	}
	log.Printf("partition IDs: %s\n", info.PartitionIDs)

	// set up wait group to wait for expected message
	eventReceived := make(chan struct{})

	// declare handler for incoming events
	handler := func(ctx context.Context, event *eventhubs.Event) error {
		//log.Printf("received: %s\n", string(event.Data))
		// notify channel that event was received
		ioStatsCollector.RecordEvent(string(event.Data))
		eventReceived <- struct{}{}
		return nil
	}

	receiveOption := eventhubs.ReceiveWithStartingOffset(persist.StartOfStream)

	for _, partitionID := range info.PartitionIDs {
		_, err := hub.Receive(
			ctx,
			partitionID,
			handler,
			receiveOption,
		)
		if err != nil {
			log.Fatalf("failed to receive for partition ID %s: %s\n", partitionID, err)
		}
	}

	lastStatsOutput := time.Now()
	lastEventReceived := time.Now()
	ticker := time.NewTicker(time.Duration(millisecondsSleep) * time.Millisecond)
	defer ticker.Stop()
	messagesProcessed := 0
	for time.Since(lastEventReceived) <= quitAfterInactiveSeconds {
		select {
		case <-eventReceived:
			lastEventReceived = time.Now()
			messagesProcessed++
		case <-ticker.C:
			if time.Since(lastStatsOutput) > statsPrintRate {
				lastStatsOutput = time.Now()
				log.Printf("event messages processed %d", messagesProcessed)
			}
		}
	}

	log.Printf("writing the files")
	ioStatsCollector.WriteRAWFiles(statsFilePath)

	log.Printf("writing the summary file")
	ioStatsCollector.WriteBatchSummaryFiles(statsFilePath)

	// 1. start the eventhub receiver
	// 2. listen for all messages, when there are no messages for a certain time,
	//    write out files:
	//    all events are collected and stored per Batch/Label.operation.csv
	//    summary: batch/summary.csv
	// CreateTimeNS    time.Duration - SampleSize, %success, P50, P75, P95, P99, P100
	// CloseTimeNS     time.Duration - SampleSize, %success, P50, P75, P95, P99, P100
	// ReadWriteTimeNS time.Duration - SampleSize, %success, P50, P75, P95, P99, P100
	// ReadWriteBytes  int  - SampleSize, %success, P50, P75, P95, P99, P100
	// 3. upon completion
	// sort
}
