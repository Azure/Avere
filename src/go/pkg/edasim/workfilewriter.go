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
	JobConfigName string
	JobRun        JobRun
	PaddedString  string
}

// InitializeWorkerFileWriter creates a work file writer for a single job
func InitializeWorkerFileWriter(
	jobConfigName string,
	jobRun *JobRun) *WorkFileWriter {
	return &WorkFileWriter{
		JobConfigName: jobConfigName,
		JobRun:        *jobRun,
	}
}

// ReadWorkFile reads a work file from disk
func ReadWorkFile(reader *file.ReaderWriter, filename string) (*WorkFileWriter, error) {
	log.Debug.Printf("[ReadWorkFile(%s)", filename)
	defer log.Debug.Printf("ReadWorkFile(%s)]", filename)
	uniqueName, runName := GetBatchNamePartsFromJobRun(filename)
	byteValue, err := reader.ReadFile(filename, uniqueName, runName)
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
func (w *WorkFileWriter) WriteStartFiles(writer *file.ReaderWriter, filepath string, fileSize int, fileCount int) error {
	log.Debug.Printf("[WriteStartFiles(%s)", filepath)
	defer log.Debug.Printf("WriteStartFiles(%s)]", filepath)
	// read once
	data, err := json.Marshal(w)
	if err != nil {
		return err
	}

	// pad and re-martial to match the bytes
	padLength := (KB * fileSize) - len(data)
	if padLength > 0 {
		w.PaddedString = random.RandStringRunesUltraFast(padLength / KB)
		data, err = json.Marshal(w)
		if err != nil {
			return err
		}
	}

	// write the files
	for i := 0; i < fileCount; i++ {
		filename := w.getStartFileName(filepath, i)
		uniqueName, runName := GetBatchNamePartsFromJobRun(filename)
		err := writer.WriteFile(filename, []byte(data), uniqueName, runName)
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
