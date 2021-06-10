// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/cachewarmer"
	"github.com/Azure/Avere/src/go/pkg/log"
)

const (
	tick                  = time.Duration(10) * time.Millisecond // 10ms
	timeBetweenBlockCheck = time.Duration(10) * time.Second      // 5 second between checking for jobs
)

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "error: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       queue the path to warm by writing the config file to the path\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func initializeApplicationVariables(ctx context.Context) (*cachewarmer.WarmPathJob, *cachewarmer.CacheWarmerQueues, bool) {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var warmTargetMountAddresses = flag.String("warmTargetMountAddresses", "", "the warm target cache filer mount addresses separated by commas")
	var warmTargetExportPath = flag.String("warmTargetExportPath", "", "the warm target export path")
	var warmTargetPath = flag.String("warmTargetPath", "", "the warm target path")

	var inclusionCsv = flag.String("inclusionCsv", "", "the inclusion list of file match strings per https://golang.org/pkg/path/filepath/#Match.  Leave blank to include everything.")
	var exclusionCsv = flag.String("exclusionCsv", "", "the exclusion list of file match strings per https://golang.org/pkg/path/filepath/#Match.  Leave blank to not exlude anything.")

	var maxFileSizeBytes = flag.Int64("maxFileSizeBytes", 0, "the maximum file size in bytes to warm.")

	var storageAccount = flag.String("storageAccountName", "", "the storage account name to host the queue")
	var storageKey = flag.String("storageKey", "", "the storage key to access the queue")
	var queueNamePrefix = flag.String("queueNamePrefix", "", "the queue name to be used for organizing the work. The queues will be created automatically")

	var blockUntilWarm = flag.Bool("blockUntilWarm", false, "the job submitter will not return until there are no more jobs")

	flag.Parse()

	if *enableDebugging {
		log.EnableDebugging()
	}

	if len(*warmTargetMountAddresses) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: warmTargetMountAddresses not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*warmTargetExportPath) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: warmTargetExportPath not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*warmTargetPath) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: warmTargetPath is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*storageAccount) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: storageAccount is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*storageKey) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: storageKey is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*queueNamePrefix) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: queueNamePrefix is not specified\n")
		usage()
		os.Exit(1)
	}

	if isValid, errorMessage := azure.ValidateQueueName(*queueNamePrefix); isValid == false {
		fmt.Fprintf(os.Stderr, "ERROR: queueNamePrefix is not valid: %s\n", errorMessage)
		usage()
		os.Exit(1)
	}

	warmJobPath := cachewarmer.InitializeWarmPathJob(
		*warmTargetMountAddresses,
		*warmTargetExportPath,
		*warmTargetPath,
		*inclusionCsv,
		*exclusionCsv,
		*maxFileSizeBytes)

	cacheWarmerQueues, err := cachewarmer.InitializeCacheWarmerQueues(
		ctx,
		*storageAccount,
		*storageKey,
		*queueNamePrefix)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: error initializing queue %v\n", err)
		os.Exit(1)
	}

	return warmJobPath, cacheWarmerQueues, *blockUntilWarm
}

func BlockUntilWarm(ctx context.Context, syncWaitGroup *sync.WaitGroup, cacheWarmerQueues *cachewarmer.CacheWarmerQueues) {
	defer syncWaitGroup.Done()
	log.Debug.Printf("[BlockUntilWarm")
	defer log.Debug.Printf("BlockUntilWarm]")

	lastCheckTime := time.Now().Add(-timeBetweenBlockCheck)
	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	jobDirectoryEmpty := false
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if time.Since(lastCheckTime) > timeBetweenBlockCheck {
				lastCheckTime = time.Now()
				if jobDirectoryEmpty {
					if isEmpty, err := cacheWarmerQueues.IsJobQueueEmpty(); err != nil {
						log.Error.Printf("error checking if job queue was empty: %v", err)
					} else if isEmpty == true {
						log.Status.Printf("job directory empty, now checking worker job directory")
						jobDirectoryEmpty = true
					}
				} else {
					if isEmpty, err := cacheWarmerQueues.IsWorkQueueEmpty(); err != nil {
						log.Error.Printf("error checking if work queue was empty: %v", err)
					} else if isEmpty == true {
						log.Status.Printf("warming complete")
						return
					}
				}
			}
		}
	}
}

func main() {
	// setup the shared context
	ctx, cancel := context.WithCancel(context.Background())

	// initialize the variables
	warmPathJob, cacheWarmerQueues, blockUntilWarm := initializeApplicationVariables(ctx)

	// write the job to the warm path
	if err := cacheWarmerQueues.WriteWarmPathJob(*warmPathJob); err != nil {
		log.Error.Printf("ERROR: encountered error while writing job: %v", err)
		os.Exit(1)
	}

	if blockUntilWarm {
		// initialize the sync wait group
		syncWaitGroup := sync.WaitGroup{}

		syncWaitGroup.Add(1)
		go BlockUntilWarm(ctx, &syncWaitGroup, cacheWarmerQueues)

		log.Info.Printf("wait for ctrl-c")
		// wait on ctrl-c
		sigchan := make(chan os.Signal, 10)
		// catch all signals will cause cancellation when mounted, we need to
		// filter out better
		// signal.Notify(sigchan)
		signal.Notify(sigchan, os.Interrupt)
		<-sigchan
		log.Info.Printf("Received ctrl-c, stopping services...")
		cancel()
		log.Info.Printf("Waiting for all processes to finish")
		syncWaitGroup.Wait()
	}

	log.Status.Printf("job submitter finished")
}
