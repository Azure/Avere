// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"

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
	fmt.Fprintf(os.Stderr, "       start the job run by queuing up jobsubmitters\n")
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

func initializeApplicationVariables() (*edasim.JobRun, string, string) {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var uniqueName = flag.String("uniqueName", "", "the unique name used to avoid queue collisions")
	var jobRunName = flag.String("jobRunName", "", "the unique job run name for this work")
	var batchCount = flag.Int("batchCount", edasim.DefaultJobCount, "the number of batches to split up the job run across")
	var jobCount = flag.Int("jobCount", edasim.DefaultJobCount, "the total number of jobs to start.  This will be divided evenly across the batchs")
	var jobFileConfigSizeKB = flag.Int("jobFileConfigSizeKB", edasim.DefaultFileSizeKB, "the jobfile size in KB to write at start of job")
	var mountParity = flag.Bool("mountParity", true, "read the file from the same mount point as it was written")

	var workStartFileConfigSizeKB = flag.Int("workStartFileConfigSizeKB", edasim.DefaultFileSizeKB, "the start work file size in KB")
	var workStartFileCount = flag.Int("workStartFileCount", edasim.DefaultWorkStartFiles, "the count of start work files")
	var workCompleteFileSizeKB = flag.Int("workCompleteFileSizeKB", 384, "the complete work file size in KB to write after job completed")
	var workCompleteFailedFileSizeKB = flag.Int("workCompleteFailedFileSizeKB", 1024, "the work file size of a failed job")
	var workFailedProbability = flag.Float64("workFailedProbability", 0.01, "the probability of a work failure")
	var workCompleteFileCount = flag.Int("workCompleteFileCount", 12, "the count of completed work files per job")
	var deleteFiles = flag.Bool("deleteFiles", true, "delete the job and work files after completion")

	flag.Parse()

	if *enableDebugging {
		log.EnableDebugging()
	}

	if envVarsAvailable := verifyEnvVars(); !envVarsAvailable {
		usage()
		os.Exit(1)
	}

	if len(*uniqueName) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: uniqueName is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*jobRunName) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: jobRunName is not specified\n")
		usage()
		os.Exit(1)
	}

	// ensure the name can be used for the queue
	azure.FatalValidateQueueName(*uniqueName)

	storageAccount := cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT)
	storageKey := cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT_KEY)

	jobRun := &edasim.JobRun{
		UniqueName:                   *uniqueName,
		JobRunName:                   *jobRunName,
		JobCount:                     *jobCount,
		BatchCount:                   *batchCount,
		JobFileConfigSizeKB:          *jobFileConfigSizeKB,
		MountParity:                  *mountParity,
		JobRunStartQueueName:         edasim.GetJobRunQueueName(*uniqueName),
		WorkStartFileSizeKB:          *workStartFileConfigSizeKB,
		WorkStartFileCount:           *workStartFileCount,
		WorkCompleteFileSizeKB:       *workCompleteFileSizeKB,
		WorkCompleteFileCount:        *workCompleteFileCount,
		WorkCompleteFailedFileSizeKB: *workCompleteFailedFileSizeKB,
		WorkFailedProbability:        *workFailedProbability,
		DeleteFiles:                  *deleteFiles,
	}

	azure.FatalValidateQueueName(jobRun.JobRunStartQueueName)

	return jobRun, storageAccount, storageKey
}

func main() {
	ctx := context.Background()

	jobRun, storageAccount, storageKey := initializeApplicationVariables()

	jobRun.SubmitBatches(ctx, storageAccount, storageKey)
}
