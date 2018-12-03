package file

import (
	"io/ioutil"
	"log"
	"os"
	"time"

	"github.com/azure/avere/src/go/pkg/telemetry"
)

// ReaderWriter records the time statistics for reading and writing files to an event hub
type ReaderWriter struct {
	label    string
	profiler telemetry.Profiler
}

// InitializeReaderWriter initializes the file reader / writer
func InitializeReaderWriter(label string, profiler telemetry.Profiler) *ReaderWriter {
	return &ReaderWriter{
		label:    label,
		profiler: profiler,
	}
}

// ReadFile reads the file bytes from the file name
func (r *ReaderWriter) ReadFile(filename string, batchName string) ([]byte, error) {
	start := time.Now()
	startReadBytes := time.Time{}
	startCloseFile := time.Time{}
	finish := time.Time{}
	var err error

	f, err := os.Open(filename)
	if err != nil {
		r.submitIOStatistics(batchName, start, ReadOperation, startReadBytes, startCloseFile, finish, NoBytesReadWritten, err)
		return nil, err
	}

	startReadBytes = time.Now()
	byteValue, err := ioutil.ReadAll(f)
	if err != nil {
		f.Close()
		r.submitIOStatistics(batchName, start, ReadOperation, startReadBytes, startCloseFile, finish, NoBytesReadWritten, err)
		return nil, err
	}

	startCloseFile = time.Now()
	err = f.Close()
	r.submitIOStatistics(batchName, start, ReadOperation, startReadBytes, startCloseFile, finish, len(byteValue), err)

	return byteValue, err
}

// WriteFile writes file bytes to the file
func (r *ReaderWriter) WriteFile(filename string, data []byte, batchName string) error {
	start := time.Now()
	startWriteBytes := time.Time{}
	startCloseFile := time.Time{}
	finish := time.Time{}

	f, err := os.Create(filename)
	if err != nil {
		r.submitIOStatistics(batchName, start, WriteOperation, startWriteBytes, startCloseFile, finish, NoBytesReadWritten, err)
		return err
	}

	startWriteBytes = time.Now()
	bytesWritten, err := f.Write(data)
	if err != nil {
		f.Close()
		r.submitIOStatistics(batchName, start, WriteOperation, startWriteBytes, startCloseFile, finish, NoBytesReadWritten, err)
		return err
	}

	startCloseFile = time.Now()
	err = f.Close()
	r.submitIOStatistics(batchName, start, WriteOperation, startWriteBytes, startCloseFile, finish, bytesWritten, err)

	return err
}

func (r *ReaderWriter) submitIOStatistics(
	batchName string,
	start time.Time,
	op Operation,
	startReadBytes time.Time,
	startCloseFile time.Time,
	finish time.Time,
	readWriteBytes int,
	err error) {

	createTimeNS := NoDuration
	if startReadBytes.After(start) {
		createTimeNS = startReadBytes.Sub(start)
	}

	readWriteTimeNS := NoDuration
	if startCloseFile.After(start) {
		readWriteTimeNS = startCloseFile.Sub(start)
	}

	closeTimeNS := NoDuration
	if finish.After(start) {
		closeTimeNS = finish.Sub(start)
	}

	ioStats := InitializeIOStatistics(
		start,
		batchName,
		r.label,
		op,
		createTimeNS,
		closeTimeNS,
		readWriteTimeNS,
		readWriteBytes,
		err)

	jsonBytes, err := ioStats.GetJSON()
	if err != nil {
		log.Printf("ERROR while submitting statistics: %v", err)
	}

	r.profiler.RecordTiming(jsonBytes)
}
