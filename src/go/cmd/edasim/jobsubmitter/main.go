package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"path"
	"sync"
	"time"

	"github.com/azure/avere/src/go/pkg/azure"
	"github.com/azure/avere/src/go/pkg/cli"
	"github.com/azure/avere/src/go/pkg/edasim"
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
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func verifyEnvVars() bool {
	available := true
	available = available && cli.VerifyEnvVar(azure.AZURE_STORAGE_ACCOUNT)
	available = available && cli.VerifyEnvVar(azure.AZURE_STORAGE_ACCOUNT_KEY)
	return available
}

func initializeApplicationVariables() (int, int, string, string, int, string, string) {
	var jobCount = flag.Int("jobCount", edasim.DefaultJobCount, "the number of jobs to start")
	var jobFileConfigSizeKB = flag.Int("jobFileConfigSizeKB", edasim.DefaultFileSizeKB, "the jobfile size in KB to write at start of job")
	var jobBaseFilePath = flag.String("jobBaseFilePath", "", "the job file path")
	var jobReadyQueueName = flag.String("jobReadyQueueName", edasim.QueueJobReady, "the job ready queue name")
	var userCount = flag.Int("userCount", edasim.DefaultUserCount, "the number of concurrent users submitting jobs")

	flag.Parse()

	if envVarsAvailable := verifyEnvVars(); !envVarsAvailable {
		usage()
		os.Exit(1)
	}

	storageAccount := cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT)
	storageKey := cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT_KEY)

	if len(*jobBaseFilePath) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: jobBaseFilePath is not specified\n")
		usage()
		os.Exit(1)
	}

	if _, err := os.Stat(*jobBaseFilePath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "ERROR: jobBaseFilePath '%s' does not exist\n", *jobBaseFilePath)
		usage()
		os.Exit(1)
	}

	if len(*jobReadyQueueName) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: jobReadyQueueName is not specified\n")
		usage()
		os.Exit(1)
	}

	if *userCount < 0 {
		fmt.Fprintf(os.Stderr, "ERROR: there must be at least 1 user to submit jobs")
		usage()
		os.Exit(1)
	}

	return *jobCount, *jobFileConfigSizeKB, *jobBaseFilePath, *jobReadyQueueName, *userCount, storageAccount, storageKey
}

func getBatchName(jobCount int) string {
	t := time.Now()
	return fmt.Sprintf("job-%02d-%02d-%02d-%02d%02d%02d-%d", t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), jobCount)
}

func main() {
	jobCount, jobFileConfigSizeKB, jobBaseFilePath, jobReadyQueueName, userCount, storageAccount, storageKey := initializeApplicationVariables()

	batchName := getBatchName(jobCount)
	jobNamePath := path.Join(jobBaseFilePath, batchName)

	if e := os.MkdirAll(jobNamePath, os.ModePerm); e != nil {
		fmt.Fprintf(os.Stderr, "ERROR: unable to create directory '%s': %v\n", jobNamePath, e)
		usage()
		os.Exit(1)
	}

	log.Printf("Starting generation of %d jobs for batch %s\n", jobCount, batchName)
	log.Printf("File Details:\n")
	log.Printf("\tJob Path: %s\n", jobNamePath)
	log.Printf("\tJob Filesize: %d\n", jobFileConfigSizeKB)
	log.Printf("usercount: %d\n", userCount)

	jobSubmitters := make([]*edasim.JobSubmitter, 0, userCount)
	jobsPerUser := jobCount / userCount
	jobsPerUserMod := jobCount % userCount

	for i := 0; i < userCount; i++ {
		storageQueue := azure.InitializeQueue(context.Background(), storageAccount, storageKey, jobReadyQueueName)
		extrajob := 0
		if i < jobsPerUserMod {
			extrajob = 1
		}
		jobSubmitter := edasim.InitializeJobSubmitter(batchName, i, storageQueue, jobsPerUser+extrajob, jobNamePath, jobFileConfigSizeKB)
		jobSubmitters = append(jobSubmitters, jobSubmitter)
	}

	userSyncWaitGroup := sync.WaitGroup{}
	userSyncWaitGroup.Add(len(jobSubmitters))

	for _, jobSubmitter := range jobSubmitters {
		go jobSubmitter.Run(&userSyncWaitGroup)
	}

	userSyncWaitGroup.Wait()
	log.Printf("Completed generation of %d jobs\n", jobCount)
}
