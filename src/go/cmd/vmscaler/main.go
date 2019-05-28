// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"sync"

	"github.com/Azure/Avere/src/go/cmd/vmscaler/vmscaler"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/cli"
	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-sdk-for-go/profiles/latest/compute/mgmt/compute"
	"github.com/Azure/go-autorest/autorest/azure/auth"
)

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "error: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       vmscaler creates and manages VMSS ensure evicted nodes are restored in a timely manner\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "required env vars:\n")
	fmt.Fprintf(os.Stderr, "\t%s - azure storage account\n", azure.AZURE_STORAGE_ACCOUNT)
	fmt.Fprintf(os.Stderr, "\t%s - azure storage account key\n", azure.AZURE_STORAGE_ACCOUNT_KEY)
	fmt.Fprintf(os.Stderr, "\t%s - Account Subscription ID\n", azure.AZURE_SUBSCRIPTION_ID)
	fmt.Fprintf(os.Stderr, "optional env vars (alternatively comes from IMDS):\n")
	fmt.Fprintf(os.Stderr, "\t%s - Account AD Tenant ID\n", azure.AZURE_TENANT_ID)
	fmt.Fprintf(os.Stderr, "\t%s - Account AD Client ID\n", azure.AZURE_CLIENT_ID)
	fmt.Fprintf(os.Stderr, "\t%s - Account AD Client Secret\n", azure.AZURE_CLIENT_SECRET)
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func verifyEnvVars() bool {
	available := true
	available = available && cli.VerifyEnvVar(azure.AZURE_SUBSCRIPTION_ID)
	available = available && cli.VerifyEnvVar(azure.AZURE_STORAGE_ACCOUNT)
	available = available && cli.VerifyEnvVar(azure.AZURE_STORAGE_ACCOUNT_KEY)
	return available
}

func initializeApplicationVariables(ctx context.Context) (*vmscaler.VMScaler, error) {
	var vnetResourceGroup = flag.String("vnetResourceGroup", "", "the virtual network resource group")
	var vnetName = flag.String("vnetName", "", "the virtual network name")
	var subnetName = flag.String("subnetName", "", "the subnet name")

	// TODO: get from resource group
	var location = flag.String("location", "westus2", "the location of the VMSS instances")

	var resourceGroup = flag.String("resourceGroup", "", "the resource group name that contains the VMSS instances")
	var vmSku = flag.String("vmSku", vmscaler.DEFAULT_SKU, "the virtual machine SKU")
	var imageId = flag.String("imageId", "", "the custom image id to use for the VMSS")
	var username = flag.String("username", "", "the username to use for VMSS virtual machines")
	var password = flag.String("password", "", "the password to use for VMSS virtual machines")
	var vmsPerVMSS = flag.Int("vmsPerVMSS", vmscaler.DEFAULT_VMS_PER_VMSS, "the number of VMs per VMSS")
	var singlePlacementGroup = flag.Bool("singlePlacementGroup", vmscaler.DEFAULT_VMSS_SINGLEPLACEMENTGROUP, "configure VMSS to span multiple tenants")
	var overProvision = flag.Bool("overProvision", vmscaler.DEFAULT_VMSS_OVERPROVISION, "configure VMSS to use overprovisioning")
	var priority = flag.String("priority", string(compute.Low), "the priority of the VMSS nodes")
	
	var debug = flag.Bool("debug", false, "enable debug output")

	flag.Parse()

	if *debug {
		log.EnableDebugging()
	}

	if envVarsAvailable := verifyEnvVars(); !envVarsAvailable {
		usage()
		os.Exit(1)
	}

	if len(*vnetResourceGroup) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: vnetResourceGroup is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*vnetName) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: vnetName is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*subnetName) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: subnetName is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*resourceGroup) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: resourceGroup is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*imageId) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: imageId is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*username) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: username is not specified\n")
		usage()
		os.Exit(1)
	}

	if len(*password) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: password is not specified\n")
		usage()
		os.Exit(1)
	}

	if *vmsPerVMSS < vmscaler.MINIMUM_VMS_PER_VMSS || *vmsPerVMSS > vmscaler.MAXIMUM_VMS_PER_VMSS {
		fmt.Fprintf(os.Stderr, "ERROR: vmsPerVMSS must be in the range [%d, %d]\n", vmscaler.MINIMUM_VMS_PER_VMSS, vmscaler.MAXIMUM_VMS_PER_VMSS)
		usage()
		os.Exit(1)
	}

	authorizer, err := auth.NewAuthorizerFromEnvironment()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: authorizer from environment failed: %s", err)
		os.Exit(1)
	}

	var computePriority compute.VirtualMachinePriorityTypes
	if strings.EqualFold(string(compute.Low), *priority) {
		computePriority = compute.Low
	} else {
		computePriority = compute.Regular
	}

	queueName := buildQueueName(vmscaler.DEFAULT_QUEUE_PREFIX, cli.GetEnv(azure.AZURE_SUBSCRIPTION_ID), *resourceGroup)
	azure.FatalValidateQueueName(queueName)

	return &vmscaler.VMScaler{
		Context:                 ctx,
		AzureTenantId:           cli.GetEnv(azure.AZURE_TENANT_ID),
		AzureClientId:           cli.GetEnv(azure.AZURE_CLIENT_ID),
		AzureClientSecret:       cli.GetEnv(azure.AZURE_CLIENT_SECRET),
		AzureSubscriptionId:     cli.GetEnv(azure.AZURE_SUBSCRIPTION_ID),
		StorageAccountName:      cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT),
		StorageAccountKey:       cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT_KEY),
		StorageAccountQueueName: queueName,
		Authorizer:              authorizer,

		VNETResourceGroup: *vnetResourceGroup,
		VNETName:          *vnetName,
		SubnetName:        *subnetName,

		// VMSS configuration values
		ResourceGroup:        *resourceGroup,
		Location:             *location,
		SKU:                  *vmSku,
		ImageID:              *imageId,
		Username:             *username,
		Password:             *password,
		VMsPerVMSS:           int64(*vmsPerVMSS),
		SinglePlacementGroup: *singlePlacementGroup,
		OverProvision:        *overProvision,
		Priority:             computePriority,
		EvictionPolicy:       compute.Delete,
	}, nil
}

func buildQueueName(queuePrefix string, subid string, resourceGroup string) string {
	return fmt.Sprintf("%s-%s-%s", queuePrefix, subid, resourceGroup)
}

func main() {
	// setup the shared context
	ctx, cancel := context.WithCancel(context.Background())
	syncWaitGroup := sync.WaitGroup{}

	// initialize and start the orchestrator
	scaler, err := initializeApplicationVariables(ctx)
	if err != nil {
		log.Error.Printf("error creating vmscaler: %v", err)
		os.Exit(1)
	}
	syncWaitGroup.Add(1)
	go scaler.Run(&syncWaitGroup)

	// wait on ctrl-c
	sigchan := make(chan os.Signal, 10)
	// catch all signals since this is to run as daemon
	signal.Notify(sigchan)
	//signal.Notify(sigchan, os.Interrupt)
	<-sigchan
	log.Info.Printf("Received ctrl-c, stopping services...")
	cancel()

	log.Info.Printf("Waiting for all processes to finish")
	syncWaitGroup.Wait()

	log.Info.Printf("finished")
}
