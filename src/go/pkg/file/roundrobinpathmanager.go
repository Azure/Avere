// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package file

import (
	"sync"
)

// RoundRobinPathManager round robins among the available paths
type RoundRobinPathManager struct {
	mux          sync.Mutex
	paths        []string
	currentIndex int
}

// InitializeRoundRobinPathManager initializes the directory manager
func InitializeRoundRobinPathManager(paths []string) *RoundRobinPathManager {
	return &RoundRobinPathManager{
		paths:        paths,
		currentIndex: -1,
	}
}

// GetNextPath retrieves the next path
func (r *RoundRobinPathManager) GetNextPath() string {
	r.mux.Lock()
	defer r.mux.Unlock()
	r.currentIndex = (r.currentIndex + 1) % len(r.paths)
	return r.paths[r.currentIndex]
}
