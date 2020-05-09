// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/signal"
	"strings"
	"time"

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

func initializeApplicationVariables() (*cachewarmer.WarmPathJob, bool) {
	var enableDebugging = flag.Bool("enableDebugging", false, "enable debug logging")
	var warmTargetMountAddresses = flag.String("warmTargetMountAddresses", "", "the warm target cache filer mount addresses separated by commas")
	var warmTargetExportPath = flag.String("warmTargetExportPath", "", "the warm target export path")
	var warmTargetPath = flag.String("warmTargetPath", "", "the warm target path")
	var jobMountAddress = flag.String("jobMountAddress", "", "the mount address for warm job processing")
	var jobExportPath = flag.String("jobExportPath", "", "the export path for warm job processing")
	var jobBasePath = flag.String("jobBasePath", "", "the warm job processing path")
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
		*jobBasePath), *blockUntilWarm
}

func BlockUntilWarm(jobSubmitterPath string, jobWorkerPath string) {
	log.Info.Printf("wait for ctrl-c")
	// wait on ctrl-c
	sigchan := make(chan os.Signal, 10)
	signal.Notify(sigchan, os.Interrupt)

	lastCheckTime := time.Now().Add(-timeBetweenBlockCheck)
	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	jobDirectoryEmpty := false
	for {
		select {
		case <-sigchan:
			log.Info.Printf("Received ctrl-c, stopping...")
			return
		case <-ticker.C:
			if time.Since(lastCheckTime) > timeBetweenBlockCheck {
				lastCheckTime = time.Now()
				if !jobDirectoryEmpty {
					// check the job directory
					files, err := ioutil.ReadDir(jobSubmitterPath)
					if err != nil {
						log.Error.Printf("error reading path %s: %v", jobSubmitterPath, err)
						continue
					}
					if len(files) == 0 {
						log.Info.Printf("Job directory empty, now checking worker job directory")
						jobDirectoryEmpty = true
					}
				} else {
					// check the worker job directory
					exists, _, err := cachewarmer.JobsExist(jobWorkerPath)
					if err != nil {
						log.Error.Printf("error encountered checking for job existence: %v", err)
					}
					if !exists {
						log.Info.Printf("warming complete")
						return
					}
				}
			}
		}
	}
}

func main() {

	// initialize the variables
	jobSubmitter, blockUntilWarm := initializeApplicationVariables()

	log.Info.Printf("job submitter %v", jobSubmitter)

	// write the job to the warm path
	if err := jobSubmitter.WriteJob(); err != nil {
		log.Error.Printf("ERROR: encountered error while writing job: %v", err)
		os.Exit(1)
	}

	if blockUntilWarm {
		jobSubmitterPath, jobWorkerPath, err := jobSubmitter.GetJobPaths()
		if err != nil {
			log.Error.Printf("ERROR: encountered while getting job paths %v", err)
			os.Exit(1)
		}
		BlockUntilWarm(jobSubmitterPath, jobWorkerPath)
	}

	log.Info.Printf("finished")
}
