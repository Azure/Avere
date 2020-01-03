// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"hash/fnv"
	"os"
	"os/signal"
	"path"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/checkpoint"
	"github.com/Azure/Avere/src/go/pkg/file"
	"github.com/Azure/Avere/src/go/pkg/log"
)

func getUniqueStr() string {
	t := time.Now()
	uniqueStr := fmt.Sprintf("%02d-%02d-%02d-%02d%02d%02d-%d", t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), t.Nanosecond())

	// generate a hashcode of the string
	h := fnv.New32a()
	h.Write([]byte(uniqueStr))

	return fmt.Sprintf("%d", h.Sum32())
}

func generateCheckpoint() {
	removeFiles := false
	samples := 10
	directoryName := "tmp"
	uniqueName := "testing"
	checkpointName := "checkpoint"
	simpleProfiler := file.InitializeSimpleProfiler()
	frw := file.InitializeReaderWriter("CheckpointWriter", simpleProfiler)
	dirMgr := file.InitializeDirectoryManager()

	for i := 0; i < samples; i++ {
		frameName := getUniqueStr()
		cpf := checkpoint.InitializeCheckpointFile(checkpointName)
		filePath := path.Join(directoryName, checkpoint.GenerateCheckpointName(uniqueName, frameName))
		dirMgr.EnsureDirectory(filePath)
		fullpath, err := cpf.WriteCheckpointFile(frw, filePath, 2*checkpoint.GB)
		if err != nil {
			log.Error.Printf("Error writing checkpoint file: %v", err)
		} else {
			log.Info.Printf("wrote checkpoint file %s", fullpath)
		}
		if removeFiles {
			os.RemoveAll(fullpath)	
		}
	}

	// finish up
	log.Info.Printf("results: %s", simpleProfiler.GetSummary())
	if removeFiles {
		os.RemoveAll(directoryName)
	}
}

func main() {
	// setup the shared context
	//ctx, cancel := context.WithCancel(context.Background())
	syncWaitGroup := sync.WaitGroup{}
	// enable debugging by default
	log.EnableDebugging()

	// wait on ctrl-c
	sigchan := make(chan os.Signal, 10)
	// catch all signals since this is to run as daemon
	signal.Notify(sigchan)
	//signal.Notify(sigchan, os.Interrupt)
	log.Info.Printf("running")
	generateCheckpoint()
	/*<-sigchan
	log.Info.Printf("Received ctrl-c, stopping services...")
	//cancel()
	*/
	log.Info.Printf("Waiting for all processes to finish")
	syncWaitGroup.Wait()

	log.Info.Printf("finished")
}