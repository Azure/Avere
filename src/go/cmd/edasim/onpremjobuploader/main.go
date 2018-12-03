package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path"
	"time"

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

func initializeApplicationVariables() (string, string, int, string, string, string, string, string, string) {
	var jobFilePath = flag.String("jobFilePath", "", "the job file path")
	var uploaderQueueName = flag.String("uploaderQueueName", "", "the uploader job queue name")
	var threadCount = flag.Int("threadCount", 1, "the number of concurrent threads uploading jobs")

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

	if len(*jobFilePath) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: jobFilePath is not specified\n")
		usage()
		os.Exit(1)
	}

	if _, err := os.Stat(*jobFilePath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "ERROR: jobFilePath '%s' does not exist\n", *jobFilePath)
		usage()
		os.Exit(1)
	}

	if len(*uploaderQueueName) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: uploaderQueueName is not specified\n")
		usage()
		os.Exit(1)
	}

	return *jobFilePath, *uploaderQueueName, *threadCount, storageAccount, storageKey, eventHubSenderName, eventHubSenderKey, eventHubNamespaceName, eventHubHubName
}

func GetJobNamePath(fullJobPath string, jobCount int) string {
	t := time.Now()
	jobName := fmt.Sprintf("job-%02d-%02d-%02d-%02d%02d%02d-%d", t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), jobCount)
	return path.Join(fullJobPath, jobName)
}

func main() {
	jobFilePath, uploaderQueueName, threadCount, storageAccount, storageKey, eventHubSenderName, eventHubSenderKey, eventHubNamespaceName, eventHubHubName := initializeApplicationVariables()

	log.Printf("Starting job uploading\n")
	log.Printf("\tJob Path: %s\n", jobFilePath)
	log.Printf("\n")
	log.Printf("Storage Details:\n")
	log.Printf("\tstorage account: %s\n", storageAccount)
	log.Printf("\tstorage account key: %s\n", storageKey)
	log.Printf("Eventhub Details:\n")
	log.Printf("\teventHubSenderName: %s\n", eventHubSenderName)
	log.Printf("\teventHubSenderKey: %s\n", eventHubSenderKey)
	log.Printf("\teventHubNamespaceName: %s\n", eventHubNamespaceName)
	log.Printf("\teventHubHubName: %s\n", eventHubHubName)
	log.Printf("\tuploader queue name: %s\n", uploaderQueueName)
	log.Printf("threadCount: %d\n", threadCount)

	// TODO - implement worker

	log.Printf("Uploader queue empty, completed uploading of jobs\n")
}
