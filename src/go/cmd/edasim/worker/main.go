package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"time"

	"github.com/azure/avere/src/go/pkg/azure"
	"github.com/azure/avere/src/go/pkg/cli"
	"github.com/azure/avere/src/go/pkg/edasim"
	"github.com/azure/avere/src/go/pkg/log"
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
	fmt.Fprintf(os.Stderr, "\t%s - azure event hub hub name\n", azure.AZURE_EVENTHUB_HUBNAME)
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
	available = available && cli.VerifyEnvVar(azure.AZURE_EVENTHUB_HUBNAME)
	return available
}

func initializeApplicationVariables() (int, string, string, string, string, string, string, string, string) {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var workerThreadCount = flag.Int("WorkerThreadCount", 2, "the count of worker threads")
	var jobProcessQueueName = flag.String("jobProcessQueueName", edasim.QueueJobProcess, "the job process queue name")
	var jobCompleteQueueName = flag.String("jobCompleteQueueName", edasim.QueueJobComplete, "the job completion queue name")

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
	eventHubHubName := cli.GetEnv(azure.AZURE_EVENTHUB_HUBNAME)

	azure.FatalValidateQueueName(*jobProcessQueueName)
	azure.FatalValidateQueueName(*jobCompleteQueueName)

	return *workerThreadCount,
		*jobProcessQueueName,
		*jobCompleteQueueName,
		storageAccount,
		storageKey,
		eventHubSenderName,
		eventHubSenderKey,
		eventHubNamespaceName,
		eventHubHubName
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())

	workerThreadCount,
		jobProcessQueueName,
		jobCompleteQueueName,
		storageAccount,
		storageKey,
		eventHubSenderName,
		eventHubSenderKey,
		eventHubNamespaceName,
		eventHubHubName := initializeApplicationVariables()

	eventHub := edasim.InitializeReaderWriters(ctx, eventHubSenderName, eventHubSenderKey, eventHubNamespaceName, eventHubHubName)

	log.Info.Printf("Starting worker\n")
	log.Info.Printf("worker thread count: %d\n", workerThreadCount)
	log.Info.Printf("storage account: %s\n", storageAccount)
	log.Info.Printf("storage account key: %s\n", storageKey)
	log.Info.Printf("job process queue name: %s\n", jobProcessQueueName)
	log.Info.Printf("job completion queue name: %s\n", jobCompleteQueueName)

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
