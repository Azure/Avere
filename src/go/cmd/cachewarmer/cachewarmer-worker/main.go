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

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/cachewarmer"
	"github.com/Azure/Avere/src/go/pkg/log"
)

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "error: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       the worker that watches for jobs, and processes them")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func initializeApplicationVariables(ctx context.Context) *cachewarmer.Worker {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var storageAccountResourceGroup = flag.String("storageAccountResourceGroup", "", "the storage account resource group")
	var storageAccount = flag.String("storageAccountName", "", "the storage account name to host the queue")
	var storageKey = flag.String("storageKey", "", "the storage key to access the queue")
	var queueNamePrefix = flag.String("queueNamePrefix", "", "the queue name to be used for organizing the work. The queues will be created automatically")

	flag.Parse()

	if *enableDebugging {
		log.EnableDebugging()
	}

	if len(*storageAccount) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: storageAccount is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*storageAccountResourceGroup) == 0 && len(*storageKey) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: storageAccountResourceGroup or storageKey must be specified\n")
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

	storageAccountKey := ""
	if len(*storageKey) != 0 {
		storageAccountKey = *storageKey
	} else {
		primaryKey, err := cachewarmer.GetPrimaryStorageKey(ctx, *storageAccountResourceGroup, *storageAccount)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: unable to get storage account key: %s", err)
			os.Exit(1)
		}
		storageAccountKey = primaryKey
	}

	cacheWarmerQueues, err := cachewarmer.InitializeCacheWarmerQueues(
		ctx,
		*storageAccount,
		storageAccountKey,
		*queueNamePrefix)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: error initializing queue %v\n", err)
		os.Exit(1)
	}

	return cachewarmer.InitializeWorker(cacheWarmerQueues)
}

func main() {
	// setup the shared context
	ctx, cancel := context.WithCancel(context.Background())

	// initialize the variables
	warmPathManager := initializeApplicationVariables(ctx)

	// initialize the sync wait group
	syncWaitGroup := sync.WaitGroup{}

	log.Status.Printf("cachwarmer worker started")
	log.Status.Printf("create worker")
	syncWaitGroup.Add(1)
	go warmPathManager.RunWorkerManager(ctx, &syncWaitGroup)

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

	log.Status.Printf("cachwarmer worker finished")
}
