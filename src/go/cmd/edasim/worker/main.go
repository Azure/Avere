package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/azure/avere/src/go/pkg/azure"
	"github.com/azure/avere/src/go/pkg/cli"
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

func validateQueue(queueName string, queueNameLabel string) {
	if len(queueName) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: %s is not specified\n", queueNameLabel)
		usage()
		os.Exit(1)
	}
}

func initializeApplicationVariables() (int, string, string, string, string, string, string, string, string) {
	var workerThreadCount = flag.Int("WorkerThreadCount", 2, "the count of worker threads")
	var jobProcessQueueName = flag.String("jobProcessQueueName", "", "the job process queue name")
	var jobCompleteQueueName = flag.String("jobCompleteQueueName", "", "the job completion queue name")

	flag.Parse()

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

	validateQueue(*jobProcessQueueName, "jobProcessQueueName")
	validateQueue(*jobCompleteQueueName, "jobCompleteQueueName")

	return *workerThreadCount, *jobProcessQueueName, *jobCompleteQueueName, storageAccount, storageKey, eventHubSenderName, eventHubSenderKey, eventHubNamespaceName, eventHubHubName
}

func main() {
	workerThreadCount, jobProcessQueueName, jobCompleteQueueName, storageAccount, storageKey, eventHubSenderName, eventHubSenderKey, eventHubNamespaceName, eventHubHubName := initializeApplicationVariables()

	log.Printf("Starting worker\n")

	log.Printf("worker thread count: %d\n", workerThreadCount)
	log.Printf("\n")
	log.Printf("Storage Details:\n")
	log.Printf("\tstorage account: %s\n", storageAccount)
	log.Printf("\tstorage account key: %s\n", storageKey)
	log.Printf("Eventhub Details:\n")
	log.Printf("\teventHubSenderName: %s\n", eventHubSenderName)
	log.Printf("\teventHubSenderKey: %s\n", eventHubSenderKey)
	log.Printf("\teventHubNamespaceName: %s\n", eventHubNamespaceName)
	log.Printf("\teventHubHubName: %s\n", eventHubHubName)
	log.Printf("job process queue name: %s\n", jobProcessQueueName)
	log.Printf("job completion queue name: %s\n", jobCompleteQueueName)

	// TODO: implement uploader
}
