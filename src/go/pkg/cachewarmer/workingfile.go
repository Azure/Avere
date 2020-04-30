// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"os"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

type WorkingFile struct {
	mux           sync.Mutex
	jobFullPath   string
	workerJob     *WorkerJob
	fileCount     int
	lastTouchFile time.Time
}

func InitializeWorkingFile(jobFullPath string, workerJob *WorkerJob) *WorkingFile {
	TouchFile(jobFullPath)
	return &WorkingFile{
		jobFullPath:   jobFullPath,
		workerJob:     workerJob,
		lastTouchFile: time.Now(),
	}
}

func (w *WorkingFile) IncrementFileToProcess() {
	w.mux.Lock()
	defer w.mux.Unlock()
	w.fileCount++
}

func (w *WorkingFile) FileProcessed() {
	w.mux.Lock()
	defer w.mux.Unlock()
	if w.fileCount > 0 {
		w.fileCount--
	}
	if w.fileCount == 0 {
		log.Info.Printf("finished processing job '%s'", w.jobFullPath)
		if err := os.Remove(w.jobFullPath); err != nil {
			log.Error.Printf("error removing working file '%s': '%v'", w.jobFullPath, err)
		}
	}
}

func (w *WorkingFile) TouchFile() {
	w.mux.Lock()
	defer w.mux.Unlock()
	if time.Since(w.lastTouchFile) > refreshWorkInterval {
		w.lastTouchFile = time.Now()
		log.Info.Printf("touch file %s", w.jobFullPath)
		TouchFile(w.jobFullPath)
	}
}
