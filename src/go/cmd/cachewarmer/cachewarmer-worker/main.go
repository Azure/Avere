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

func initializeApplicationVariables() *cachewarmer.Worker {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var jobMountAddress = flag.String("jobMountAddress", "", "the mount address for warm job processing")
	var jobExportPath = flag.String("jobExportPath", "", "the export path for warm job processing")
	var jobBasePath = flag.String("jobBasePath", "", "the warm job processing path")

	flag.Parse()

	if *enableDebugging {
		log.EnableDebugging()
	}

	if len(*jobMountAddress) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: jobMountAddress is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*jobExportPath) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: jobExportPath is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*jobBasePath) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: jobBasePath is not specified\n")
		usage()
		os.Exit(1)
	}

	jobWorkerPath, err := cachewarmer.EnsureWorkerJobPath(*jobMountAddress, *jobExportPath, *jobBasePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: error ensuring job worker path %v", err)
		os.Exit(1)
	}

	return cachewarmer.InitializeWorker(jobWorkerPath)
}

func main() {
	// setup the shared context
	ctx, cancel := context.WithCancel(context.Background())

	// initialize the variables
	warmPathManager := initializeApplicationVariables()

	// initialize the sync wait group
	syncWaitGroup := sync.WaitGroup{}

	log.Info.Printf("create worker")
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

	log.Info.Printf("finished")
}
