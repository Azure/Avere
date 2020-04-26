// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	
	"github.com/Azure/Avere/src/go/pkg/cachewarmer"
	"github.com/Azure/Avere/src/go/pkg/log"
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

func initializeApplicationVariables() *cachewarmer.WarmPathJob {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var warmTargetMountAddresses = flag.String("warmTargetMountAddresses", "", "the warm target cache filer mount addresses separated by commas")
	var warmTargetExportPath = flag.String("warmTargetExportPath", "", "the warm target export path")
	var warmTargetPath = flag.String("warmTargetPath", "", "the warm target path")
	var jobMountAddress = flag.String("jobMountAddress", "", "the mount address for warm job processing")
	var jobExportPath = flag.String("jobExportPath", "", "the export path for warm job processing")
	var jobBasePath = flag.String("jobBasePath", "", "the warm job processing path")

	flag.Parse()

	if *enableDebugging {
		log.EnableDebugging()
	}

	if len(*warmTargetMountAddresses) == 0 {
		fmt.Fprintf(os.Stderr, "ERROR: warmTargetMountAddresses not specified\n")
		usage()
		os.Exit(1)
	}
	targetMountAddessSlice := strings.Split(*warmTargetMountAddresses, ",")

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

	return cachewarmer.InitializeWarmPathJob(
		targetMountAddessSlice,
		*warmTargetExportPath,
		*warmTargetPath,
		*jobMountAddress,
		*jobExportPath,
		*jobBasePath)
}

func main() {

	// initialize the variables
	jobSubmitter := initializeApplicationVariables()

	log.Info.Printf("job submitter %v", jobSubmitter)

	// write the job to the warm path
	if err := jobSubmitter.WriteJob(); err != nil {
		log.Error.Printf("ERROR: encountered error while writing job: %v", err)
		os.Exit(1)
	}

	log.Info.Printf("finished")
}
