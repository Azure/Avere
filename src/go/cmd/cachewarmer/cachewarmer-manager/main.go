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

	"github.com/Azure/go-autorest/autorest/azure/auth"
)

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "error: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       the manager that watches for warm jobs, and")
	fmt.Fprintf(os.Stderr, "       starts VMSS to handle the warm path worker jobs\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "optional env vars (alternatively comes from IMDS):\n")
	fmt.Fprintf(os.Stderr, "\t%s - Account AD Tenant ID\n", azure.AZURE_TENANT_ID)
	fmt.Fprintf(os.Stderr, "\t%s - Account AD Client ID\n", azure.AZURE_CLIENT_ID)
	fmt.Fprintf(os.Stderr, "\t%s - Account AD Client Secret\n", azure.AZURE_CLIENT_SECRET)
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func initializeApplicationVariables() (*cachewarmer.WarmPathManager, bool) {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var runAsService = flag.Bool("runAsService", false, "enable running as service")
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

	authorizer, err := auth.NewAuthorizerFromEnvironment()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: authorizer from environment failed: %s", err)
		os.Exit(1)
	}

	jobSubmitterPath, err := cachewarmer.EnsureJobSubmitterPath(*jobMountAddress, *jobExportPath, *jobBasePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: error ensuring job submitter path %v", err)
		os.Exit(1)
	}

	jobWorkerPath, err := cachewarmer.EnsureWorkerJobPath(*jobMountAddress, *jobExportPath, *jobBasePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: error ensuring job worker path %v", err)
		os.Exit(1)
	}

	return cachewarmer.InitializeWarmPathManager(
			authorizer,
			jobSubmitterPath,
			jobWorkerPath),
		*runAsService
}

func main() {
	// setup the shared context
	ctx, cancel := context.WithCancel(context.Background())

	// initialize the variables
	warmPathManager, runAsService := initializeApplicationVariables()

	// initialize the sync wait group
	syncWaitGroup := sync.WaitGroup{}

	log.Info.Printf("create job generator")
	syncWaitGroup.Add(1)
	go warmPathManager.RunJobGenerator(ctx, &syncWaitGroup)

	log.Info.Printf("create the vmss manager")
	syncWaitGroup.Add(1)
	go warmPathManager.RunVMSSManager(ctx, &syncWaitGroup)

	log.Info.Printf("wait for ctrl-c")
	// wait on ctrl-c
	sigchan := make(chan os.Signal, 10)
	if runAsService {
		// catch all signals since this is to run as daemon
		signal.Notify(sigchan)
	} else {
		signal.Notify(sigchan, os.Interrupt)
	}

	<-sigchan
	log.Info.Printf("Received ctrl-c, stopping services...")
	cancel()
	log.Info.Printf("Waiting for all processes to finish")
	syncWaitGroup.Wait()

	log.Info.Printf("finished")
}
