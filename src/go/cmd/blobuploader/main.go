package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/cli"
	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/Avere/src/go/pkg/random"

	"github.com/google/uuid"
)

// BlobUploader handles all the blob uploads
type BlobUploader struct {
	Context            context.Context
	BlobContainer      *azure.BlobContainer
	BlobSizeBytes      int64
	BlobCount          int
	ThreadCount        int
	BlobsUploaded      int
	FailureCount       int
	BytesUploaded      int64
	JobRunTime         time.Duration
	uploadBytesChannel chan int64
	failureChannel     chan struct{}
	successChannel     chan int64
}

// InitializeBlobUploader initializes the blob uploader
func InitializeBlobUploader(
	ctx context.Context,
	storageAccount string,
	storageAccountKey string,
	blobContainerName string,
	blobSizeBytes int64,
	blobCount int,
	threadCount int) (*BlobUploader, error) {
	blobContainer, err := azure.InitializeBlobContainer(ctx, storageAccount, storageAccountKey, blobContainerName)
	if err != nil {
		return nil, err
	}
	return &BlobUploader{
		Context:            ctx,
		BlobContainer:      blobContainer,
		BlobSizeBytes:      blobSizeBytes,
		BlobCount:          blobCount,
		ThreadCount:        threadCount,
		uploadBytesChannel: make(chan int64),
		successChannel:     make(chan int64),
		failureChannel:     make(chan struct{}),
	}, nil
}

// Run starts the upload workers
func (b *BlobUploader) Run(syncWaitGroup *sync.WaitGroup) {
	start := time.Now()
	defer func() { b.JobRunTime = time.Now().Sub(start) }()
	log.Info.Printf("started BlobUploader.Run()\n")
	defer syncWaitGroup.Done()

	var cancel context.CancelFunc
	b.Context, cancel = context.WithCancel(b.Context)

	// start the ready queue listener and its workers
	// this uses the example from here: https://github.com/Azure/azure-storage-queue-go/blob/master/2017-07-29/azqueue/zt_examples_test.go
	for i := 0; i < b.ThreadCount; i++ {
		syncWaitGroup.Add(1)
		go b.StartBlobUploader(syncWaitGroup)
	}

	// dispatch jobs to the workers
	dispatchedCount := 0
	for dispatchedCount < b.BlobCount {
		select {
		case <-b.Context.Done():
			return
		case b.uploadBytesChannel <- b.BlobSizeBytes:
			dispatchedCount++
		case msg := <-b.uploadBytesChannel:
			b.BlobsUploaded++
			b.BytesUploaded += msg
		case <-b.failureChannel:
			b.FailureCount++
		}
	}

	// wait for completion
	for {
		select {
		case msg := <-b.uploadBytesChannel:
			b.BlobsUploaded++
			b.BytesUploaded += msg
		case <-b.failureChannel:
			b.FailureCount++
		}
		if (b.BlobsUploaded + b.FailureCount) == b.BlobCount {
			cancel()
			return
		}
	}
}

// StartBlobUploader starts the blob uploader
func (b *BlobUploader) StartBlobUploader(syncWaitGroup *sync.WaitGroup) {
	defer syncWaitGroup.Done()
	log.Info.Printf("[StartBlobUploader")
	defer log.Info.Printf("completed StartBlobUploader]")

	for {
		// handle the messages
		select {
		case <-b.Context.Done():
			return
		case msg := <-b.uploadBytesChannel:
			b.uploadBlob(msg)
		}
	}
}

// PrintStats prints out the statistics
func (b *BlobUploader) PrintStats() {
	log.Info.Printf("Blobs Uploaded: %d / %d (%f failure rate)", b.BlobsUploaded, b.BlobCount, float32(b.FailureCount)/float32(b.BlobCount))
	log.Info.Printf("MB/s Upload Rate: %f", float64(b.BytesUploaded)/(b.JobRunTime.Seconds()*float64(1024*1024)))
}

// defines the blob contents
type BlobContents struct {
	Name         string
	PaddedString string
}

func (b *BlobUploader) uploadBlob(bytes int64) {
	blobContents := &BlobContents{
		Name: uuid.New().String(),
	}

	// learn the size of the current object
	data, err := json.Marshal(blobContents)
	if err != nil {
		log.Error.Printf("error encountered marshalling blob %v", err)
		b.failureChannel <- struct{}{}
		return
	}

	// pad and re-martial to match the bytes
	padLength := bytes - int64(len(data))
	if padLength > 0 {
		blobContents.PaddedString = random.RandStringRunes(int(padLength))
		data, err = json.Marshal(blobContents)
		if err != nil {
			log.Error.Printf("error encountered marshalling blob %v", err)
			b.failureChannel <- struct{}{}
			return
		}
	}

	if err := b.BlobContainer.UploadBlob(blobContents.Name, data); err != nil {
		log.Error.Printf("failed to upload blob %v", err)
	} else {
		select {
		case <-b.Context.Done():
			return
		case b.uploadBytesChannel <- bytes:
		}
	}
}

func usage(errs ...error) {
	for _, err := range errs {
		fmt.Fprintf(os.Stderr, "error: %s\n\n", err.Error())
	}
	fmt.Fprintf(os.Stderr, "usage: %s [OPTIONS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "       write the job config file and posts to the queue\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "required env vars:\n")
	fmt.Fprintf(os.Stderr, "\t%s - azure storage account\n", azure.AZURE_STORAGE_ACCOUNT)
	fmt.Fprintf(os.Stderr, "\t%s - azure storage account key\n", azure.AZURE_STORAGE_ACCOUNT_KEY)
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "options:\n")
	flag.PrintDefaults()
}

func verifyEnvVars() bool {
	available := true
	available = available && cli.VerifyEnvVar(azure.AZURE_STORAGE_ACCOUNT)
	available = available && cli.VerifyEnvVar(azure.AZURE_STORAGE_ACCOUNT_KEY)
	return available
}

// GetContainerName generates a container based on time
func GetContainerName(blobCount int) string {
	t := time.Now()
	return fmt.Sprintf("job-%02d-%02d-%02d-%02d%02d%02d-%d", t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), blobCount)
}

func initializeApplicationVariables(ctx context.Context) (*BlobUploader, error) {
	var blobFileSizeKB = flag.Int("blobFileSizeKB", 8*1024, "the blob file size in KB")
	var blobCount = flag.Int("blobCount", 12, "the count of threads")
	var threadCount = flag.Int("threadCount", 12, "the count of threads")

	flag.Parse()

	if envVarsAvailable := verifyEnvVars(); !envVarsAvailable {
		usage()
		os.Exit(1)
	}

	containerName := GetContainerName(*blobCount)
	azure.FatalValidateContainerName(containerName)

	storageAccount := cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT)
	storageKey := cli.GetEnv(azure.AZURE_STORAGE_ACCOUNT_KEY)

	return InitializeBlobUploader(
		ctx,
		storageAccount,
		storageKey,
		containerName,
		int64(*blobFileSizeKB)*int64(1024),
		*blobCount,
		*threadCount)
}

func main() {
	// setup the shared context
	ctx := context.Background()
	syncWaitGroup := sync.WaitGroup{}

	// initialize and start the orchestrator
	blobUploader, err := initializeApplicationVariables(ctx)
	if err != nil {
		log.Error.Printf("error creating blob uploader: %v", err)
		os.Exit(1)
	}
	syncWaitGroup.Add(1)
	go blobUploader.Run(&syncWaitGroup)

	log.Info.Printf("Waiting for all processes to finish")
	syncWaitGroup.Wait()

	blobUploader.PrintStats()

	log.Info.Printf("finished")
}
