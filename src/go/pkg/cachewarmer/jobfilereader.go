// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
// Package cachewarmer implements the structures, methods, and functions used by the cache warmer
package cachewarmer

import (
	"io"
	"math/rand"
	"os"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

type JobFileReader struct {
	f             *os.File
	files         []string
	filesIndex    int
	jobWorkerPath string
	lastSeenEOF   time.Time
	mux           sync.Mutex
}

func NewJobFileReader(jobpath string) *JobFileReader {
	return &JobFileReader{
		f:             nil,
		files:         make([]string, 0),
		filesIndex:    0,
		jobWorkerPath: jobpath,
		lastSeenEOF:   time.Now().Add(-timeBetweenEOF),
	}
}

func (j *JobFileReader) GetNextFilename() string {
	j.mux.Lock()
	defer j.mux.Unlock()

	if time.Since(j.lastSeenEOF) < timeBetweenEOF {
		return ""
	}

	// return a file if there is one remaining
	filename := j.getNextFilename()
	if len(filename) > 0 {
		return filename
	}

	if j.readDirs() == true {
		return j.getNextFilename()
	}

	j.lastSeenEOF = time.Now()
	return ""
}

func (j *JobFileReader) readDirs() bool {
	iterationCount := 1
	if j.f != nil {
		// the file handle is open, loop a second time to get the latest files
		iterationCount += 1
	}

	for i := 0; i < iterationCount; i++ {
		if j.f == nil && j.openFile() == false {
			return false
		}

		begin := time.Now()
		files, err := j.f.Readdirnames(MinimumJobsOnDirRead)
		log.Info.Printf("Readdirnames took %v", time.Now().Sub(begin))

		if err != nil && err != io.EOF {
			log.Error.Printf("error reading dirnames from directory '%s': '%v'", j.jobWorkerPath, err)
			j.f.Close()
			j.f = nil
			continue
		}

		if err != nil && err == io.EOF {
			log.Error.Printf("EOF encountered '%s': '%v'", j.jobWorkerPath, err)
			j.f.Close()
			j.f = nil
			continue
		}

		if len(files) == 0 {
			j.f.Close()
			j.f = nil
			continue
		} else {
			j.files = randomizeFiles(files)
			j.filesIndex = 0
			return true
		}
	}
	return false
}

func randomizeFiles(files []string) []string {
	sliceSize := len(files)
	randomFiles := make([]string, 0, sliceSize)

	index := rand.Intn(sliceSize)
	for i := 0; i < sliceSize; i++ {
		randomFiles = append(randomFiles, files[index])
		index = (index + PrimeIndexIncr) % sliceSize
	}
	return randomFiles
}

func (j *JobFileReader) openFile() bool {
	f, err := os.Open(j.jobWorkerPath)
	if err != nil {
		log.Error.Printf("error reading files from directory '%s': '%v'", j.jobWorkerPath, err)
		return false
	}
	j.f = f
	return true
}

func (j *JobFileReader) getNextFilename() string {
	if j.filesIndex < len(j.files) {
		filename := j.files[j.filesIndex]
		j.filesIndex += 1
		return filename
	}
	return ""
}
