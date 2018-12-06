package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path"
	"strings"
	"sync"
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

func initializeApplicationVariables() (int, int, []string, string, int, string, string, string, string, string, string) {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var jobCount = flag.Int("jobCount", edasim.DefaultJobCount, "the number of jobs to start")
	var jobFileConfigSizeKB = flag.Int("jobFileConfigSizeKB", edasim.DefaultFileSizeKB, "the jobfile size in KB to write at start of job")
	var jobBaseFilePathCSV = flag.String("jobBaseFilePathCSV", "", "one or more job file paths separated by commas")
	var jobReadyQueueName = flag.String("jobReadyQueueName", edasim.QueueJobReady, "the job ready queue name")
	var userCount = flag.Int("userCount", edasim.DefaultUserCount, "the number of concurrent users submitting jobs")

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

	if len(*jobBaseFilePathCSV) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: jobBaseFilePathCSV is not specified\n")
		usage()
		os.Exit(1)
	}

	jobBaseFilePaths := strings.Split(*jobBaseFilePathCSV, ",")

	for _, path := range jobBaseFilePaths {
		if _, err := os.Stat(path); os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "ERROR: jobBaseFilePath '%s' does not exist\n", path)
			usage()
			os.Exit(1)
		}
	}

	azure.FatalValidateQueueName(*jobReadyQueueName)

	if *userCount < 0 {
		fmt.Fprintf(os.Stderr, "ERROR: there must be at least 1 user to submit jobs")
		usage()
		os.Exit(1)
	}

	return *jobCount,
		*jobFileConfigSizeKB,
		jobBaseFilePaths,
		*jobReadyQueueName,
		*userCount,
		storageAccount,
		storageKey,
		eventHubSenderName,
		eventHubSenderKey,
		eventHubNamespaceName,
		eventHubHubName
}

func initializeJobSubmitters(
	ctx context.Context,
	userCount int,
	jobCount int,
	storageAccount string,
	storageKey string,
	jobReadyQueueName string,
	jobBaseFilePaths []string,
	jobFileConfigSizeKB int) []*edasim.JobSubmitter {

	batchName := edasim.GenerateBatchName(jobCount)

	jobNamePaths := make([]string, 0, len(jobBaseFilePaths))

	for _, jobBaseFilePath := range jobBaseFilePaths {
		jobNamePath := path.Join(jobBaseFilePath, batchName)

		if e := os.MkdirAll(jobNamePath, os.ModePerm); e != nil {
			log.Error.Printf("unable to create directory '%s': %v\n", jobNamePath, e)
			usage()
			os.Exit(1)
		}

		jobNamePaths = append(jobNamePaths, jobNamePath)
	}

	jobSubmitters := make([]*edasim.JobSubmitter, 0, userCount)

	jobsPerUser := jobCount / userCount
	jobsPerUserMod := jobCount % userCount

	for i := 0; i < userCount; i++ {
		storageQueue := azure.InitializeQueue(ctx, storageAccount, storageKey, jobReadyQueueName)

		// count the extra job if job count doesn't nicely dived into the number of users
		extrajob := 0
		if i < jobsPerUserMod {
			extrajob = 1
		}

		jobSubmitters = append(jobSubmitters, edasim.InitializeJobSubmitter(ctx, batchName, i, storageQueue, jobsPerUser+extrajob, jobNamePaths, jobFileConfigSizeKB))
	}

	return jobSubmitters
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())

	jobCount,
		jobFileConfigSizeKB,
		jobBaseFilePaths,
		jobReadyQueueName,
		userCount,
		storageAccount,
		storageKey,
		eventHubSenderName,
		eventHubSenderKey,
		eventHubNamespaceName,
		eventHubHubName := initializeApplicationVariables()

	eventHub := edasim.InitializeReaderWriters(ctx, eventHubSenderName, eventHubSenderKey, eventHubNamespaceName, eventHubHubName)

	// start the stats collector
	statsChannelWaitGroup := sync.WaitGroup{}
	ctx = edasim.SetStatsChannel(ctx)
	statsChannelWaitGroup.Add(1)
	go edasim.StatsCollector(ctx, &statsChannelWaitGroup)

	log.Info.Printf("Starting job submission of %d jobs for batch %s\n", jobCount, edasim.GenerateBatchName(jobCount))

	jobSubmitters := initializeJobSubmitters(ctx, userCount, jobCount, storageAccount, storageKey, jobReadyQueueName, jobBaseFilePaths, jobFileConfigSizeKB)

	userSyncWaitGroup := sync.WaitGroup{}
	userSyncWaitGroup.Add(len(jobSubmitters))

	for _, jobSubmitter := range jobSubmitters {
		go jobSubmitter.Run(&userSyncWaitGroup)
	}

	// wait for the job submitters (users) to finish
	userSyncWaitGroup.Wait()

	// close the stats channel, and wait for it to complete
	cancel()
	statsChannelWaitGroup.Wait()

	log.Info.Printf(" wait for the event hub sender to complete")

	for {
		if eventHub.IsSenderComplete() {
			break
		} else {
			time.Sleep(time.Duration(10) * time.Millisecond)
		}
	}

	log.Info.Printf("Completed job submission of %d jobs\n", jobCount)
}
