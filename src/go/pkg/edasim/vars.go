package edasim

import (
	"context"
	"fmt"
	"os"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/file"
	"github.com/Azure/Avere/src/go/pkg/log"
)

var (
	// JobWriter is the writer used for job files
	JobWriter *file.ReaderWriter
	// JobReader is the reader used for readung job files
	JobReader *file.ReaderWriter

	// WorkStartFileWriter is the writer used for work start files
	WorkStartFileWriter *file.ReaderWriter
	// WorkStartFileReader is the reader used for work start files
	WorkStartFileReader *file.ReaderWriter

	// WorkCompleteFileWriter is the writer used for work complete files
	WorkCompleteFileWriter *file.ReaderWriter
	// WorkCompleteFileReader is the reader used for work complete files
	WorkCompleteFileReader *file.ReaderWriter

	// JobCompleteWriter is the writer used for job complete files
	JobCompleteWriter *file.ReaderWriter
	// JobCompleteReader is the reader used for job complete files
	JobCompleteReader *file.ReaderWriter
)

// InitializeReaderWriters initializes the reader writers with event hub profiling
func InitializeReaderWriters(
	ctx context.Context,
	eventHubSenderName string,
	eventHubSenderKey string,
	eventHubNamespaceName string,
	eventHubHubName string) *azure.EventHubSender {

	log.Info.Printf("InitializeReaderWriters %s, %s", eventHubNamespaceName, eventHubHubName)
	eventHub, e := azure.InitializeEventHubSender(
		ctx,
		eventHubSenderName,
		eventHubSenderKey,
		eventHubNamespaceName,
		eventHubHubName)

	if e != nil {
		log.Error.Printf("unable to initialize event hub sender.  Failed with error: %v\n", e)
		os.Exit(1)
	}

	initializeReaderWriters(eventHub)

	return eventHub
}

func initializeReaderWriters(eventHub *azure.EventHubSender) {
	JobWriter = file.InitializeReaderWriter(JobWriterLabel, eventHub)
	JobReader = file.InitializeReaderWriter(JobReaderLabel, eventHub)

	WorkStartFileWriter = file.InitializeReaderWriter(WorkStartFileWriterLabel, eventHub)
	WorkStartFileReader = file.InitializeReaderWriter(WorkStartFileReaderLabel, eventHub)

	WorkCompleteFileWriter = file.InitializeReaderWriter(WorkCompleteFileWriterLabel, eventHub)
	WorkCompleteFileReader = file.InitializeReaderWriter(WorkCompleteFileReaderLabel, eventHub)

	JobCompleteWriter = file.InitializeReaderWriter(JobCompleteWriterLabel, eventHub)
	JobCompleteReader = file.InitializeReaderWriter(JobCompleteReaderLabel, eventHub)
}

// GetEventHubName returns the event hub name
func GetEventHubName(uniqueName string) string {
	return fmt.Sprintf("%s-edasim", uniqueName)
}

// GetJobRunQueueName returns the job run queue name
func GetJobRunQueueName(uniqueName string) string {
	return fmt.Sprintf("%s-jobrun", uniqueName)
}

// GetJobStartQueueName returns the job run queue name
func GetJobStartQueueName(uniqueName string) string {
	return fmt.Sprintf("%s-jobstart", uniqueName)
}

// GetWorkStartQueueName returns the work start queue name
func GetWorkStartQueueName(uniqueName string) string {
	return fmt.Sprintf("%s-workstart", uniqueName)
}

// GetWorkCompleteQueueName returns the work complete queue name
func GetWorkCompleteQueueName(uniqueName string) string {
	return fmt.Sprintf("%s-workcomplete", uniqueName)
}

// GetJobCompleteQueueName returns the job complete queue name
func GetJobCompleteQueueName(uniqueName string) string {
	return fmt.Sprintf("%s-jobcomplete", uniqueName)
}
