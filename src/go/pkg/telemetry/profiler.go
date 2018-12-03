package telemetry

// Profiler implements profiling methods
type Profiler interface {
	RecordTiming(bytes []byte)
}
