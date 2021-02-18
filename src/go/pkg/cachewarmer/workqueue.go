// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"sync"
)

type FileToWarm struct {
	WarmFileFullPath string
	StartByte        int64
	StopByte         int64
}

func InitializeFileToWarm(warmFilePath string, startByte int64, stopByte int64) FileToWarm {
	return FileToWarm{
		WarmFileFullPath: warmFilePath,
		StartByte:        startByte,
		StopByte:         stopByte,
	}
}

// RoundRobinPathManager round robins among the available paths
type WorkQueue struct {
	mux       sync.Mutex
	workItems []FileToWarm
}

func InitializeWorkQueue() *WorkQueue {
	return &WorkQueue{}
}

func (q *WorkQueue) IsEmpty() bool {
	q.mux.Lock()
	defer q.mux.Unlock()
	return len(q.workItems) == 0
}

func (q *WorkQueue) WorkItemCount() int {
	q.mux.Lock()
	defer q.mux.Unlock()
	return len(q.workItems)
}

// GetNextWorkItem retrieves the next workItem
func (q *WorkQueue) GetNextWorkItem() (FileToWarm, bool) {
	q.mux.Lock()
	defer q.mux.Unlock()
	if len(q.workItems) > 0 {
		result := q.workItems[len(q.workItems)-1]
		q.workItems[len(q.workItems)-1] = FileToWarm{}
		q.workItems = q.workItems[:len(q.workItems)-1]
		return result, true
	} else {
		return FileToWarm{}, false
	}
}

func (q *WorkQueue) AddWorkItem(fileToWarm FileToWarm) {
	q.mux.Lock()
	defer q.mux.Unlock()
	q.workItems = append(q.workItems, fileToWarm)
}
