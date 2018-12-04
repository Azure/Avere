package log

// Profiler implements profiling methods
type Profiler interface {
	RecordTiming(bytes []byte)
}
