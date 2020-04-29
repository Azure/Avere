// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"sync"
)

type ReaderCounter struct {
	mux         sync.Mutex
	readerCount int
}

func InitializeReaderCounter() *ReaderCounter {
	return &ReaderCounter{}
}

func (r *ReaderCounter) ReadersExist() bool {
	r.mux.Lock()
	defer r.mux.Unlock()
	return r.readerCount > 0
}

func (r *ReaderCounter) ReadersEmpty() bool {
	r.mux.Lock()
	defer r.mux.Unlock()
	return r.readerCount == 0
}

func (r *ReaderCounter) AddReader() {
	r.mux.Lock()
	defer r.mux.Unlock()
	r.readerCount++
}

func (r *ReaderCounter) RemoveReader() {
	r.mux.Lock()
	defer r.mux.Unlock()
	r.readerCount--
}
