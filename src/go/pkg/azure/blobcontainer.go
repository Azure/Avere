package azure

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"regexp"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-storage-blob-go/azblob"
)

const (
	productionBlobURLTemplate = "https://%s.blob.core.windows.net"
)

// BlobContainer represents a blob container, this can be used to read/write blockblobs, appendblobs, or page blobs
// The implementation has been influenced by https://github.com/Azure/azure-storage-blob-go/blob/master/azblob/zt_examples_test.go
// RESTAPI: https://docs.microsoft.com/en-us/rest/api/storageservices/blob-service-rest-api
// AZBLOB: https://godoc.org/github.com/Azure/azure-storage-blob-go/azblob#pkg-examples
type BlobContainer struct {
	ContainerURL azblob.ContainerURL
	Context      context.Context
}

// FatalValidateContainerName exits the program if the containername is not valid
func FatalValidateContainerName(containerName string) {
	isValid, errorMessage := ValidateContainerName(containerName)
	if !isValid {
		log.Error.Printf(errorMessage)
		os.Exit(1)
	}
}

// ValidateContainerName validates container name according to https://docs.microsoft.com/en-us/rest/api/storageservices/create-container
func ValidateContainerName(containerName string) (bool, string) {
	matched, err := regexp.MatchString("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", containerName)

	if err != nil {
		errorMessage := fmt.Sprintf("error while parsing container Name '%s' to server: %v", containerName, err)
		return false, errorMessage
	}

	if !matched {
		errorMessage := fmt.Sprintf("'%s' is not a valid queue name.  Blob container needs to be 3-63 lowercase alphanumeric characters where all but the first and last character may be dash (https://docs.microsoft.com/en-us/rest/api/storageservices/create-container)", containerName)
		return false, errorMessage
	}
	return true, ""
}

// InitializeBlob creates a Blob to represent the Azure Storage Queue
func InitializeBlobContainer(ctx context.Context, storageAccount string, storageAccountKey string, containerName string) (*BlobContainer, error) {

	credential, err := azblob.NewSharedKeyCredential(storageAccount, storageAccountKey)
	if err != nil {
		log.Error.Printf("encountered error while creating new shared key credential %v", err)
		return nil, err
	}

	p := azblob.NewPipeline(credential, azblob.PipelineOptions{})

	u, _ := url.Parse(fmt.Sprintf(productionBlobURLTemplate, storageAccount))

	serviceURL := azblob.NewServiceURL(*u, p)

	// Create a URL that references the blob container in the Azure Storage account.
	containerURL := serviceURL.NewContainerURL(containerName)

	// create the container if it does not already exist
	if containerCreateResponse, err := containerURL.Create(ctx, azblob.Metadata{}, azblob.PublicAccessNone); err != nil {
		if serr, ok := err.(azblob.StorageError); !ok || serr.ServiceCode() != azblob.ServiceCodeContainerAlreadyExists {
			log.Error.Printf("error encountered: %v", serr.ServiceCode())
			return nil, err
		}
	} else if containerCreateResponse.StatusCode() == 201 {
		log.Info.Printf("successfully created blob container '%s'", containerName)
	}

	return &BlobContainer{
		ContainerURL: containerURL,
		Context:      ctx,
	}, nil
}

// UploadBlob uploads the blob to the container
func (b *BlobContainer) UploadBlob(blobname string, data []byte) error {
	blobURL := b.ContainerURL.NewBlockBlobURL(blobname)
	if _, err := azblob.UploadBufferToBlockBlob(b.Context, data, blobURL, azblob.UploadToBlockBlobOptions{}); err != nil {
		log.Error.Printf("encountered error uploading blob '%s': '%v'", blobname, err)
		return err
	}
	return nil
}

// DownloadBlob downloads the bytes of the blob
func (b *BlobContainer) DownloadBlob(blobname string) ([]byte, error) {
	blobURL := b.ContainerURL.NewBlobURL(blobname)
	blobProperties, err := blobURL.GetProperties(b.Context, azblob.BlobAccessConditions{})
	if err != nil {
		log.Error.Printf("encountered error getting blob properties for '%s': '%v'", blobname, err)
		return nil, err
	}
	data := make([]byte, 0, blobProperties.ContentLength())
	if err := azblob.DownloadBlobToBuffer(b.Context, blobURL, 0, 0, data, azblob.DownloadFromBlobOptions{}); err != nil {
		log.Error.Printf("encountered error downloading blob '%s': '%v'", blobname, err)
		return nil, err
	}
	return data, nil
}

// DeleteBlob deletes the blob
func (b *BlobContainer) DeleteBlob(blobname string) error {
	blobURL := b.ContainerURL.NewBlobURL(blobname)
	if _, err := blobURL.Delete(b.Context, azblob.DeleteSnapshotsOptionNone, azblob.BlobAccessConditions{}); err != nil {
		log.Error.Printf("encountered error deleting blob '%s': '%v'", blobname, err)
		return err
	}
	return nil
}
