// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"context"
	"flag"
	"fmt"
	"hash/fnv"
	"os"
	"os/signal"
	"path"
	"runtime/debug"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/checkpoint"
	"github.com/Azure/Avere/src/go/pkg/file"
	"github.com/Azure/Avere/src/go/pkg/log"
)

type contextkey string

const sigChanKey contextkey = "sigChanKey"
const cancelKey contextkey = "cancelKey"

const (
	DefaultCheckpointSizeBytes = 2 * checkpoint.GB
	DefaultDebugMode           = false
	DefaultRemoveFiles         = true
	DefaultTrialRuns           = 0
	DefaultTargetDirectory     = "tmp"
	DefaultUniqueName          = "simtest"

	DefaultCheckpointName = "checkpoint"
	DefaultTrialName      = "CheckpointWriter"
)

type CheckpointSim struct {
	CheckpointSizeBytes uint
	RemoveFiles         bool
	TrialRuns           uint
	TargetDirectory     string
	UniqueName          string
}

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "ERROR: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       use trial runs to measure the performance of checkpoint trial runs\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func initializeApplicationVariables() *CheckpointSim {
	var checkpointSizeBytes = flag.Uint("checkpointSizeBytes", DefaultCheckpointSizeBytes, "the size of checkpoint to write")
	var removeFiles = flag.Bool("removeFiles", DefaultRemoveFiles, "specify to remove the checkpoint files on each trial run")
	var trialRuns = flag.Uint("trialRuns", DefaultTrialRuns, "the number of trial runs")
	var targetDirectory = flag.String("targetDirectory", DefaultTargetDirectory, "the target directory for checkpoint file creation")
	var uniqueName = flag.String("uniqueName", DefaultUniqueName, "a name to identify the trial run")

	var debug = flag.Bool("debug", DefaultDebugMode, "enable debug output")

	flag.Parse()

	if *debug {
		log.EnableDebugging()
	}

	if *trialRuns == DefaultTrialRuns {
		usage(fmt.Errorf("ERROR: specify a minimum of 1 trial run"))
		os.Exit(1)
	}
	return &CheckpointSim{
		CheckpointSizeBytes: *checkpointSizeBytes,
		RemoveFiles:         *removeFiles,
		TrialRuns:           *trialRuns,
		TargetDirectory:     *targetDirectory,
		UniqueName:          *uniqueName,
	}
}

func getUniqueStr() string {
	t := time.Now()
	uniqueStr := fmt.Sprintf("%02d-%02d-%02d-%02d%02d%02d-%d", t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), t.Nanosecond())

	// generate a hashcode of the string
	h := fnv.New32a()
	h.Write([]byte(uniqueStr))

	return fmt.Sprintf("%d", h.Sum32())
}

func isCancelled(ctx context.Context) bool {
	v := ctx.Value(sigChanKey)
	sigchan := v.(chan os.Signal)

	v2 := ctx.Value(cancelKey)
	cancel := v2.(context.CancelFunc)

	select {
	case <-ctx.Done():
		return true
	case <-sigchan:
		cancel()
		return true
	default:
		return false
	}
}

func generateCheckpoint(ctx context.Context, syncWaitGroup *sync.WaitGroup, checkpointSim *CheckpointSim) {
	log.Debug.Printf("[generateCheckpoint")
	defer log.Debug.Printf("generateCheckpoint]")
	defer syncWaitGroup.Done()

	simpleProfiler := file.InitializeSimpleProfiler()
	frw := file.InitializeReaderWriter(DefaultTrialName, simpleProfiler)
	dirMgr := file.InitializeDirectoryManager()

	for i := uint(0); i < checkpointSim.TrialRuns; i++ {
		if isCancelled(ctx) {
			break
		}
		frameName := getUniqueStr()
		cpf := checkpoint.InitializeCheckpointFile(DefaultCheckpointName)
		filePath := path.Join(checkpointSim.TargetDirectory, checkpoint.GenerateCheckpointName(checkpointSim.UniqueName, frameName))
		dirMgr.EnsureDirectory(filePath)
		fullpath, err := cpf.WriteCheckpointFile(frw, filePath, 2*checkpoint.GB)
		if err != nil {
			log.Error.Printf("Error writing checkpoint file: %v", err)
		} else {
			log.Info.Printf("wrote checkpoint file %s", fullpath)
		}
		if checkpointSim.RemoveFiles {
			os.RemoveAll(fullpath)
		}
		cpf.Payload = nil
		cpf = nil
		// need to force clear the memory or this will lead to OOM for large checkpoints
		debug.FreeOSMemory()
	}

	// finish up
	log.Info.Printf("results: %s", simpleProfiler.GetSummary())
	if checkpointSim.RemoveFiles {
		os.RemoveAll(checkpointSim.TargetDirectory)
	}
}

func main() {
	// setup the shared context
	ctx, cancel := context.WithCancel(context.Background())
	syncWaitGroup := sync.WaitGroup{}

	checkpointSimVars := initializeApplicationVariables()

	// wait on ctrl-c
	sigchan := make(chan os.Signal, 10)
	// catch all signals since this is to run as daemon
	signal.Notify(sigchan)
	ctx = context.WithValue(ctx, sigChanKey, sigchan)
	ctx = context.WithValue(ctx, cancelKey, cancel)

	syncWaitGroup.Add(1)
	generateCheckpoint(ctx, &syncWaitGroup, checkpointSimVars)

	log.Info.Printf("Waiting for all processes to finish")
	syncWaitGroup.Wait()

	log.Info.Printf("finished")
}
