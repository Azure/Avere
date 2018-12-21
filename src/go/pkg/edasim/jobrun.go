package edasim

import (
	"context"
	"encoding/json"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/log"
)

// JobRun describes the details of a full job run including how many batches to break it into
type JobRun struct {
	// the unique name identifies the queue and eventhub, this avoids multiple people having colisions
	UniqueName string

	// the job run details
	JobRunName string
	JobCount   int
	BatchCount int
	BatchID    int

	// job start and end file information
	JobFileConfigSizeKB int

	// mount information
	MountParity bool

	// job queue information
	JobRunStartQueueName         string
	WorkStartFileSizeKB          int
	WorkStartFileCount           int
	WorkCompleteFileSizeKB       int
	WorkCompleteFileCount        int
	WorkCompleteFailedFileSizeKB int
	WorkFailedProbability        float64
	DeleteFiles                  bool
}

// InitializeJobRunFromString reads a jobrun from json string
func InitializeJobRunFromString(jobRunString string) (*JobRun, error) {
	log.Debug.Printf("[InitializeJobRunFromString ")
	defer log.Debug.Printf("InitializeJobRunFromString ]")

	var result JobRun
	if err := json.Unmarshal([]byte(jobRunString), &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// SubmitBatches submits the necessary batches into the queue
func (j *JobRun) SubmitBatches(ctx context.Context, storageAccount string, storageKey string) {

	jobRunQueue := azure.InitializeQueue(ctx, storageAccount, storageKey, j.JobRunStartQueueName)

	for i := 0; i < j.BatchCount; i++ {
		j.BatchID = i
		log.Info.Printf("enqueing batch %d", j.BatchID)
		jobRunString, err := j.getJobRunString()
		if err != nil {
			log.Error.Printf("error getting JSON: %v", err)
			continue
		}
		if err := jobRunQueue.Enqueue(jobRunString); err != nil {
			log.Error.Printf("error enqueuing message '%s': %v", jobRunString, err)
			continue
		}
	}
}

// GetJobRunString returns the JSON representation of the jobrun
func (j *JobRun) getJobRunString() (string, error) {
	log.Debug.Printf("[GetJobRunString()")
	defer log.Debug.Printf("GetJobRunString()]")

	data, err := json.Marshal(j)
	if err != nil {
		return "", err
	}
	return string(data), nil
}
