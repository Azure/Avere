// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package stats

// EventHubSender sends messages to Azure Event Hub
type NilProfiler struct {
}

// InitializeNilProfiler initializes a nil profiler
func InitializeNilProfiler() (*NilProfiler) {
	return &NilProfiler{}
}

// RecordTiming implements interface Profiler
func (n *NilProfiler) RecordTiming(bytes []byte) {
}
