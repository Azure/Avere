// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package azure

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-pipeline-go/pipeline"
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

func getCustomHTTPClient() *http.Client {
	/*proxyURL, err := url.Parse("http://127.0.0.1:8888")
	if err != nil {
		log.Fatal(err)
	}*/

	AnthonyBernieDialer := func(network, addr string) (net.Conn, error) {
		//log.Info.Printf("[AnthonyBernieDialier %s, %s", network, addr)
		//defer log.Info.Printf("AnthonyBernieDialier]")
		/*ipAddr, err := net.ResolveIPAddr(network, addr)
		if err != nil {
			return nil, err
		}
		ipconn, err := net.DialIP(network, nil, ipAddr)
		if err != nil {
			return nil, err
		}
		if err := ipconn.SetWriteBuffer(8454144); err != nil {
			return nil, err
		}
		return ipconn, nil*/
		tcpAddr, err := net.ResolveTCPAddr(network, addr)
		if err != nil {
			return nil, err
		}
		tcpconn, err := net.DialTCP(network, nil, tcpAddr)
		if err != nil {
			return nil, err
		}
		if err := tcpconn.SetWriteBuffer(8454144); err != nil {
			return nil, err
		}
		return tcpconn, nil

		/*conn, err := (&net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
			DualStack: true,
		}).Dial(network, addr)

		if err != nil {
			return conn, err
		}

		ipconn := conn.(net.IPConn)*/
		/*ipconn := &net.IPConn{
			conn: conn,
		}*/

	}
	log.Info.Printf("using the AnthonyBernieDialier")
	// We want the Transport to have a large connection pool
	return &http.Client{
		Transport: &http.Transport{
			//Proxy: http.ProxyURL(proxyURL),
			// We use Dial instead of DialContext as DialContext has been reported to cause slower performance.
			Dial /*Context*/ :      AnthonyBernieDialer, /*Context*/
			MaxIdleConns:           0,                   // No limit
			MaxIdleConnsPerHost:    100,
			IdleConnTimeout:        90 * time.Second,
			TLSHandshakeTimeout:    10 * time.Second,
			ExpectContinueTimeout:  1 * time.Second,
			DisableKeepAlives:      false,
			DisableCompression:     false,
			MaxResponseHeaderBytes: 0,
			//ResponseHeaderTimeout:  time.Duration{},
			//ExpectContinueTimeout:  time.Duration{},
		},
	}
}

var pipelineHTTPClient = getCustomHTTPClient()

// AnthonyBernieDefaultHTTPClientFactory creates a DefaultHTTPClientPolicyFactory object that sends HTTP requests to a Go's default http.Client.
func AnthonyBernieDefaultHTTPClientFactory() pipeline.Factory {
	return pipeline.FactoryFunc(func(next pipeline.Policy, po *pipeline.PolicyOptions) pipeline.PolicyFunc {
		return func(ctx context.Context, request pipeline.Request) (pipeline.Response, error) {
			//r, err := newDefaultHTTPClient().Do(request.WithContext(ctx))
			r, err := pipelineHTTPClient.Do(request.WithContext(ctx))
			if err != nil {
				err = pipeline.NewError(err, "HTTP request failed")
			}
			return pipeline.NewHTTPResponse(r), err
		}
	})
}

// InitializeBlob creates a Blob to represent the Azure Storage Queue
func InitializeBlobContainer(ctx context.Context, storageAccount string, storageAccountKey string, containerName string) (*BlobContainer, error) {

	credential, err := azblob.NewSharedKeyCredential(storageAccount, storageAccountKey)
	if err != nil {
		log.Error.Printf("encountered error while creating new shared key credential %v", err)
		return nil, err
	}

	//p := azblob.NewSuperPipeline(credential, azblob.PipelineOptions{}, AnthonyBernieDefaultHTTPClientFactory())
	p := azblob.NewPipeline(credential, azblob.PipelineOptions{})

	u, _ := url.Parse(fmt.Sprintf(productionBlobURLTemplate, storageAccount))

	serviceURL := azblob.NewServiceURL(*u, p)

	// Create a URL that references the blob container in the Azure Storage account.
	containerURL := serviceURL.NewContainerURL(containerName)

	// create the container if it does not already exist
	log.Info.Printf("trying to create blob container '%s'", containerName)
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
	start := time.Now()
	defer func() {
		log.Info.Printf("Upload Bob %s (delta %v)]", blobname, time.Now().Sub(start))
	}()

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
	blobProperties, err := blobURL.GetProperties(b.Context, azblob.BlobAccessConditions{}, azblob.ClientProvidedKeyOptions{})
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
