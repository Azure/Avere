package file

import (
	"io/ioutil"
	"os"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

// ReaderWriter records the time statistics for reading and writing files to an event hub
type ReaderWriter struct {
	label    string
	profiler log.Profiler
}

// InitializeReaderWriter initializes the file reader / writer
func InitializeReaderWriter(label string, profiler log.Profiler) *ReaderWriter {
	return &ReaderWriter{
		label:    label,
		profiler: profiler,
	}
}

// ReadFile reads the file bytes from the file name
func (r *ReaderWriter) ReadFile(filename string, uniqueName string, runName string) ([]byte, error) {
	start := time.Now()
	startReadBytes := time.Time{}
	startCloseFile := time.Time{}
	finish := time.Time{}
	var err error

	f, err := os.Open(filename)
	if err != nil {
		r.submitIOStatistics(uniqueName, runName, start, ReadOperation, filename, startReadBytes, startCloseFile, finish, NoIOBytes, err)
		return nil, err
	}

	startReadBytes = time.Now()
	byteValue, err := ioutil.ReadAll(f)
	if err != nil {
		f.Close()
		r.submitIOStatistics(uniqueName, runName, start, ReadOperation, filename, startReadBytes, startCloseFile, finish, len(byteValue), err)
		return nil, err
	}

	startCloseFile = time.Now()
	err = f.Close()
	finish = time.Now()
	r.submitIOStatistics(uniqueName, runName, start, ReadOperation, filename, startReadBytes, startCloseFile, finish, len(byteValue), err)

	return byteValue, err
}

// WriteFile writes file bytes to the file
func (r *ReaderWriter) WriteFile(filename string, data []byte, uniqueName string, runName string) error {
	start := time.Now()
	startWriteBytes := time.Time{}
	startCloseFile := time.Time{}
	finish := time.Time{}

	f, err := os.Create(filename)
	if err != nil {
		r.submitIOStatistics(uniqueName, runName, start, WriteOperation, filename, startWriteBytes, startCloseFile, finish, NoIOBytes, err)
		return err
	}

	startWriteBytes = time.Now()
	bytesWritten, err := f.Write(data)
	if err != nil {
		f.Close()
		r.submitIOStatistics(uniqueName, runName, start, WriteOperation, filename, startWriteBytes, startCloseFile, finish, bytesWritten, err)
		return err
	}

	startCloseFile = time.Now()
	err = f.Close()
	finish = time.Now()
	r.submitIOStatistics(uniqueName, runName, start, WriteOperation, filename, startWriteBytes, startCloseFile, finish, bytesWritten, err)

	return err
}

func (r *ReaderWriter) submitIOStatistics(
	uniqueName string,
	runName string,
	start time.Time,
	op Operation,
	path string,
	startReadBytesTime time.Time,
	startCloseFileTime time.Time,
	finish time.Time,
	ioBytes int,
	err error) {

	if err != nil {
		log.Error.Printf("%s io error '%s' (iobytes: %d): %v", op, path, ioBytes, err)
	}

	fileOpenTimeNS := NoDuration
	if !startReadBytesTime.Before(start) {
		fileOpenTimeNS = startReadBytesTime.Sub(start)
	}

	ioTimeNS := NoDuration
	if !startCloseFileTime.Before(startReadBytesTime) {
		ioTimeNS = startCloseFileTime.Sub(startReadBytesTime)
	}

	closeTimeNS := NoDuration
	if !finish.Before(startCloseFileTime) {
		closeTimeNS = finish.Sub(startCloseFileTime)
	}

	ioStats := InitializeIOStatistics(
		start,
		uniqueName,
		runName,
		r.label,
		op,
		path,
		fileOpenTimeNS,
		closeTimeNS,
		ioTimeNS,
		ioBytes,
		err)

	jsonBytes, err := ioStats.GetJSON()
	if err != nil {
		log.Error.Printf("error encountered submitting statistics: %v", err)
		return
	}
	log.Debug.Printf(string(jsonBytes))
	r.profiler.RecordTiming(jsonBytes)
}
