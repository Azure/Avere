package main

import (
	"flag"
	"fmt"
	"log"
	"os"
)

const (
	AZURE_STORAGE_ACCOUNT     = "AZURE_STORAGE_ACCOUNT"
	AZURE_STORAGE_ACCOUNT_KEY = "AZURE_STORAGE_ACCOUNT_KEY"
)

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "error: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       write the job config file and posts to the queue\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "required env vars:\n")
	fmt.Fprintf(os.Stderr, "\t%s - azure storage account\n", AZURE_STORAGE_ACCOUNT)
	fmt.Fprintf(os.Stderr, "\t%s - azure storage account key\n", AZURE_STORAGE_ACCOUNT_KEY)
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func verifyEnvVar(envvar string) bool {
	if _, available := os.LookupEnv(envvar); !available {
		fmt.Fprintf(os.Stderr, "ERROR: Missing Environment Variable %s\n", envvar)
		return false
	}
	return true
}

func verifyEnvVars() bool {
	available := true
	available = available && verifyEnvVar(AZURE_STORAGE_ACCOUNT)
	available = available && verifyEnvVar(AZURE_STORAGE_ACCOUNT_KEY)
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

func initializeApplicationVariables() (int, string, string, string, string) {
	var workerThreadCount = flag.Int("WorkerThreadCount", 2, "the count of worker threads")
	var jobProcessQueueName = flag.String("jobProcessQueueName", "", "the job process queue name")
	var jobCompleteQueueName = flag.String("jobCompleteQueueName", "", "the job completion queue name")

	flag.Parse()

	if envVarsAvailable := verifyEnvVars(); !envVarsAvailable {
		usage()
		os.Exit(1)
	}

	storageAccount := getEnv(AZURE_STORAGE_ACCOUNT)
	storageKey := getEnv(AZURE_STORAGE_ACCOUNT_KEY)

	validateQueue(*jobProcessQueueName, "jobProcessQueueName")
	validateQueue(*jobCompleteQueueName, "jobCompleteQueueName")

	return *workerThreadCount, *jobProcessQueueName, *jobCompleteQueueName, storageAccount, storageKey
}

func main() {
	workerThreadCount, jobProcessQueueName, jobCompleteQueueName, storageAccount, storageKey := initializeApplicationVariables()

	log.Printf("Starting worker\n")

	log.Printf("worker thread count: %d\n", workerThreadCount)
	log.Printf("\n")
	log.Printf("Storage Details:\n")
	log.Printf("\tstorage account: %s\n", storageAccount)
	log.Printf("\tstorage account key: %s\n", storageKey)
	log.Printf("job process queue name: %s\n", jobProcessQueueName)
	log.Printf("job completion queue name: %s\n", jobCompleteQueueName)

	// TODO: implement uploader
}
