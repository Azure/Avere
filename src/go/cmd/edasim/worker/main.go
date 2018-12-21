package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"time"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/cli"
	"github.com/Azure/Avere/src/go/pkg/edasim"
	"github.com/Azure/Avere/src/go/pkg/log"
)

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "error: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       write the job config file and posts to the queue\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "required env vars:\n")
	fmt.Fprintf(os.Stderr, "\t%s - azure storage account\n", azure.AZURE_STORAGE_ACCOUNT)
	fmt.Fprintf(os.Stderr, "\t%s - azure storage account key\n", azure.AZURE_STORAGE_ACCOUNT_KEY)
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub sender name\n", azure.AZURE_EVENTHUB_SENDERKEYNAME)
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub sender key\n", azure.AZURE_EVENTHUB_SENDERKEY)
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub namespace name\n", azure.AZURE_EVENTHUB_NAMESPACENAME)
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func verifyEnvVars() bool {
	available := true
	available = available && cli.VerifyEnvVar(azure.AZURE_STORAGE_ACCOUNT)
	available = available && cli.VerifyEnvVar(azure.AZURE_STORAGE_ACCOUNT_KEY)
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_SENDERKEYNAME)
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_SENDERKEY)
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_NAMESPACENAME)
	return available
}

func initializeApplicationVariables(ctx context.Context) (*azure.EventHubSender, string, string, string, []string, int) {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var uniqueName = flag.String("uniqueName", "", "the unique name to avoid queue collisions")
	var mountPathsCSV = flag.String("mountPathsCSV", "", "one mount paths separated by commas")
	var threadCount = flag.Int("threadCount", 16, "the count of worker threads")

	flag.Parse()

	if *enableDebugging {
		log.EnableDebugging()
	}

	if envVarsAvailable := verifyEnvVars(); !envVarsAvailable {
		usage()
		os.Exit(1)
	}

	storageAccount := cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT)
	storageKey := cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT_KEY)
	eventHubSenderName := cli.GetEnv(azure.AZURE_EVENTHUB_SENDERKEYNAME)
	eventHubSenderKey := cli.GetEnv(azure.AZURE_EVENTHUB_SENDERKEY)
	eventHubNamespaceName := cli.GetEnv(azure.AZURE_EVENTHUB_NAMESPACENAME)

	if len(*uniqueName) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: uniqueName is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*mountPathsCSV) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: mountPathsCSV is not specified\n")
		usage()
		os.Exit(1)
	}

	mountPaths := strings.Split(*mountPathsCSV, ",")

	for _, path := range mountPaths {
		if _, err := os.Stat(path); os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "ERROR: mountPath '%s' does not exist\n", path)
			usage()
			os.Exit(1)
		} else if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: error encountered with path '%s': %v\n", path, err)
			usage()
			os.Exit(1)
		}
	}

	azure.FatalValidateQueueName(*uniqueName)

	if *threadCount < 0 {
		fmt.Fprintf(os.Stderr, "ERROR: there must be at least 1 thread to submit jobs")
		usage()
		os.Exit(1)
	}

	eventHub := edasim.InitializeReaderWriters(
		ctx,
		eventHubSenderName,
		eventHubSenderKey,
		eventHubNamespaceName,
		edasim.GetEventHubName(*uniqueName))

	return eventHub,
		storageAccount,
		storageKey,
		*uniqueName,
		mountPaths,
		*threadCount
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())

	eventHub,
		storageAccount,
		storageKey,
		uniqueName,
		mountPaths,
		workerThreadCount := initializeApplicationVariables(ctx)

	log.Info.Printf("Starting worker\n")
	log.Info.Printf("worker thread count: %d\n", workerThreadCount)
	log.Info.Printf("storage account: %s\n", storageAccount)
	log.Info.Printf("length of storage account key: %d\n", len(storageKey))
	log.Info.Printf("unique name: %s\n", uniqueName)
	log.Info.Printf("length of mount paths: %d\n", len(mountPaths))

	// TODO: implement worker

	// wait on ctrl-c
	sigchan := make(chan os.Signal, 10)
	// catch all signals since this is to run as daemon
	signal.Notify(sigchan)
	//signal.Notify(sigchan, os.Interrupt)
	<-sigchan
	log.Info.Printf("Received ctrl-c, stopping services...")
	cancel()

	log.Info.Printf("wait for the event hub sender to complete")

	for {
		if eventHub.IsSenderComplete() {
			break
		} else {
			time.Sleep(time.Duration(10) * time.Millisecond)
		}
	}

	log.Info.Printf("worker finished\n")
}
