// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package file

import (
	"fmt"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

// EventHubSender sends messages to Azure Event Hub
type SimpleProfiler struct {
	mux         sync.Mutex
	ioStatsRows *IOStatsRows
}

// InitializeSimpleProfiler initializes a simple profiler
func InitializeSimpleProfiler() (*SimpleProfiler) {
	return &SimpleProfiler{
		ioStatsRows: InitializeIOStatsRows(),
	}
}

// RecordTiming implements interface Profiler
func (s *SimpleProfiler) RecordTiming(bytes []byte) {
	if iostatRow, err := InitializeIOStatisticsFromString(string(bytes)); err != nil {
		log.Error.Printf("error encountered recording timing statistics: %v", err)
		return
	} else {
		s.ioStatsRows.AddIOStats(iostatRow)
	}
}

func (s *SimpleProfiler) GetSummary() string {
	var totalTimeNS time.Duration
	totalBytes := 0
	rows := s.ioStatsRows.GetRows()
	if len(rows) == 0 {
		return fmt.Sprintf("0 samples")
	}
	for _, row := range rows {
		totalTimeNS += row.FileOpenTimeNS
		totalTimeNS += row.FileCloseTimeNS
		totalTimeNS += row.IOTimeNS
		totalBytes += row.IOBytes
	}
	log.Debug.Printf("seconds: %v, bytes: %v", totalTimeNS.Seconds(),totalBytes)
	return fmt.Sprintf("%d samples, %v GB/s", len(rows), (float64(totalBytes) / totalTimeNS.Seconds()) / (1024.0*1024.0*1024.0) )
}