// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"sync"
)

// RoundRobinPathManager round robins among the available paths
type WorkQueue struct {
	mux       sync.Mutex
	workItems []string
}

const (
	WorkItemStartSize = 1024
)

func InitializeWorkQueue() *WorkQueue {
	return &WorkQueue{
		workItems: make([]string, 0, WorkItemStartSize),
	}
}

func (q *WorkQueue) IsEmpty() bool {
	q.mux.Lock()
	defer q.mux.Unlock()
	return len(q.workItems) == 0
}

// GetNextWorkItem retrieves the next workItem
func (q *WorkQueue) GetNextWorkItem() (string, bool) {
	q.mux.Lock()
	defer q.mux.Unlock()
	if len(q.workItems) > 0 {
		result := q.workItems[len(q.workItems)-1]
		q.workItems[len(q.workItems)-1] = ""
		q.workItems = q.workItems[:len(q.workItems)-1]
		return result, true
	} else {
		return "", false
	}
}

func (q *WorkQueue) AddWork(filepaths []string) {
	q.mux.Lock()
	defer q.mux.Unlock()
	q.workItems = append(q.workItems, filepaths...)
}
