// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package log

// Profiler implements profiling methods
type Profiler interface {
	RecordTiming(bytes []byte)
}
