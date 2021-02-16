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
	fmt.Fprintf(os.Stderr, "       the manager that watches for warm jobs, and starts VMSS to handle the warm path worker jobs\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "optional env vars (alternatively comes from IMDS):\n")
	fmt.Fprintf(os.Stderr, "\t%s - Account AD Tenant ID\n", azure.AZURE_TENANT_ID)
	fmt.Fprintf(os.Stderr, "\t%s - Account AD Client ID\n", azure.AZURE_CLIENT_ID)
	fmt.Fprintf(os.Stderr, "\t%s - Account AD Client Secret\n", azure.AZURE_CLIENT_SECRET)
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func initializeApplicationVariables() *cachewarmer.WarmPathManager {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var bootstrapMountAddress = flag.String("bootstrapMountAddress", "", "the mount address that hosts the worker bootstrap script")
	var bootstrapExportPath = flag.String("bootstrapExportPath", "", "the export path that hosts the worker bootstrap script")
	var bootstrapScriptPath = flag.String("bootstrapScriptPath", "", "the path to the worker bootstrap script")

	var storageAccount = flag.String("storageAccountName", "", "the storage account name to host the queue")
	var storageKey = flag.String("storageKey", "", "the storage key to access the queue")
	var queueNamePrefix = flag.String("queueNamePrefix", "", "the queue name to be used for organizing the work. The queues will be created automatically")

	var vmssUserName = flag.String("vmssUserName", "", "the username for the vmss vms")
	var vmssPassword = flag.String("vmssPassword", "", "(optional) the password for the vmss vms, this is unused if the public key is specified")
	var vmssSshPublicKey = flag.String("vmssSshPublicKey", "", "(optional) the ssh public key for the vmss vms, this will be used by default, however if this is blank, the password will be used")
	var vmssSubnetName = flag.String("vmssSubnetName", "", "(optional) the subnet to use for the VMSS, if not specified use the same subnet as the controller")

	flag.Parse()

	if *enableDebugging {
		log.EnableDebugging()
	}

	if len(*bootstrapMountAddress) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: bootstrapMountAddress is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*bootstrapExportPath) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: bootstrapExportPath is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*bootstrapScriptPath) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: bootstrapScriptPath is not specified\n")
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

	if isValid, errorMessage := ValidateQueueName(*queueNamePrefix); isValid == false {
		fmt.Fprintf(os.Stderr, "ERROR: queueNamePrefix is not valid: %s\n", errorMessage)
		usage()
		os.Exit(1)
	}

	if len(*vmssUserName) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: userName for the VMSS is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*vmssPassword) == 0 && len(*vmssSshPublicKey) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: either password or sshPublicKey must be specified\n")
		usage()
		os.Exit(1)
	}

	azureClients, err := cachewarmer.InitializeAzureClients()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: unable to initialize Azure Clients: %s", err)
		os.Exit(1)
	}

	cacheWarmerQueues, err := cachewarmer.InitializeCacheWarmerQueues(
		ctx,
		*storageAccount,
		*storageKey,
		*queueNamePrefix)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: error initializing queue %v\n", err)
		os.Exit(1)
	}

	return cachewarmer.InitializeWarmPathManager(
		azureClients,
		*bootstrapMountAddress,
		*bootstrapExportPath,
		*bootstrapScriptPath,
		*vmssUserName,
		*vmssPassword,
		*vmssSshPublicKey,
		*vmssSubnetName,
		cacheWarmerQueues,
	)
}

func main() {
	// setup the shared context
	ctx, cancel := context.WithCancel(context.Background())

	// initialize the variables
	warmPathManager := initializeApplicationVariables()

	// initialize the sync wait group
	syncWaitGroup := sync.WaitGroup{}

	log.Status.Printf("cachewarmer manager started")

	log.Status.Printf("create job generator")
	syncWaitGroup.Add(1)
	go warmPathManager.RunJobGenerator(ctx, &syncWaitGroup)

	log.Status.Printf("create the vmss manager")
	syncWaitGroup.Add(1)
	go warmPathManager.RunVMSSManager(ctx, &syncWaitGroup)

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

	log.Status.Printf("cachewarmer manager finished")
}
