package edasim

import (
	"encoding/json"
	"fmt"
	"path"

	"github.com/Azure/Avere/src/go/pkg/file"
	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/Avere/src/go/pkg/random"
)

// WorkFileWriter handles the work start file and complete file creation for a single job
type WorkFileWriter struct {
	JobConfigName            string
	StartFileSizeKB          int
	StartFileCount           int
	CompleteFileSizeKB       int
	CompleteFileCount        int
	CompleteFailedFileSizeKB int
	FailedProbability        float64
	PaddedString             string
}

// InitializeWorkerFileWriter creates a work file writer for a single job
func InitializeWorkerFileWriter(
	jobConfigName string,
	startFileSizeKB int,
	startFileCount int,
	completeFileSizeKB int,
	completeFileCount int,
	completeFailedFileSizeKB int,
	failedProbability float64) *WorkFileWriter {
	return &WorkFileWriter{
		JobConfigName:            jobConfigName,
		StartFileSizeKB:          startFileSizeKB,
		StartFileCount:           startFileCount,
		CompleteFileSizeKB:       completeFileSizeKB,
		CompleteFileCount:        completeFileCount,
		CompleteFailedFileSizeKB: completeFailedFileSizeKB,
		FailedProbability:        failedProbability,
	}
}

// ReadWorkFile reads a work file from disk
func ReadWorkFile(reader *file.ReaderWriter, filename string) (*WorkFileWriter, error) {
	log.Debug.Printf("[ReadWorkFile(%s)", filename)
	defer log.Debug.Printf("ReadWorkFile(%s)]", filename)
	byteValue, err := reader.ReadFile(filename, GetBatchName(filename))
	if err != nil {
		return nil, err
	}

	var result WorkFileWriter
	if err := json.Unmarshal([]byte(byteValue), &result); err != nil {
		return nil, err
	}

	// clear the padded string for GC
	result.PaddedString = ""
	return &result, nil
}

// WriteStartFiles writes the required number of start files
func (w *WorkFileWriter) WriteStartFiles(writer *file.ReaderWriter, filepath string, fileSize int) error {
	log.Debug.Printf("[WriteStartFiles(%s)", filepath)
	defer log.Debug.Printf("WriteStartFiles(%s)]", filepath)
	// read once
	data, err := json.Marshal(w)
	if err != nil {
		return err
	}

	// pad and re-martial to match the bytes
	padLength := (KB * 384) - len(data)
	if padLength > 0 {
		w.PaddedString = random.RandStringRunes(padLength)
		data, err = json.Marshal(w)
		if err != nil {
			return err
		}
	}

	// write the files
	for i := 0; i < w.StartFileCount; i++ {
		filename := w.getStartFileName(filepath, i)
		err := writer.WriteFile(filename, []byte(data), GetBatchName(filename))
		if err != nil {
			return err
		}
	}

	return nil
}

// FirstStartFile returns the path of the first start file
func (w *WorkFileWriter) FirstStartFile(filepath string) string {
	return w.getStartFileName(filepath, 0)
}

func (w *WorkFileWriter) getStartFileName(filepath string, index int) string {
	return path.Join(filepath, fmt.Sprintf("%s.start.%d", w.JobConfigName, index))
}
