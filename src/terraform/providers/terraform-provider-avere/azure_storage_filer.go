// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"strings"
)

const (
	BucketContentsEmpty = "empty"
	BucketContentsUsed  = "used"
	BucketDelimeter     = "/"
)

// GetAzureStorageAccount returns the container from
// the bucket string.  The bucket is in the format
// "accountname/container", this extracts the container
func GetAzureStorageAccount(bucketName string) string {
	results := strings.Split(bucketName, BucketDelimeter)
	if len(results) > 0 {
		return results[0]
	}
	// delimiter missing, just return the full string
	return bucketName
}

// GetAzureStorageContainer returns the container from
// the bucket string.  The bucket is in the format
// "accountname/container", this extracts the container
func GetAzureStorageContainer(bucketName string) string {
	results := strings.Split(bucketName, BucketDelimeter)
	if len(results) > 1 {
		return results[1]
	}
	// delimiter missing, just return the full string
	return bucketName
}

// GetCloudFilerName returns the name is used for the name of the
// cloud credentials, and the core filer
func (a *AzureStorageFiler) GetBucketName() string {
	return fmt.Sprintf("%s%s%s", a.AccountName, BucketDelimeter, a.Container)
}

// GetCloudFilerName returns the name is used for the name of the
// cloud credentials, and the core filer
func (a *AzureStorageFiler) GetCloudFilerName() string {
	return GetCloudFilerName(a.AccountName, a.Container)
}

// GetCloudFilerName returns the name is used for the name of the
// cloud credentials, and the core filer
func GetCloudFilerName(storageAccountName string, containerName string) string {
	return fmt.Sprintf("%s.%s", storageAccountName, containerName)
}

// GetBucketContents returns the appropriate value depending on
// whether the container is empty or not
func (a *AzureStorageFiler) GetBucketContents(avereVfxt *AvereVfxt) (string, error) {
	bucketEmpty, err := BucketEmpty(avereVfxt, a.AccountName, a.Container)
	if err != nil {
		return "", err
	}
	if bucketEmpty {
		return BucketContentsEmpty, nil
	} else {
		return BucketContentsUsed, nil
	}
}

// PrepareForFilerCreation ensures the storage account is ready
// for cloudfilercreation
func (a *AzureStorageFiler) PrepareForFilerCreation(avereVfxt *AvereVfxt) error {
	bucketExists, err := BucketExists(avereVfxt, a.AccountName, a.Container)
	if err != nil {
		return err
	}
	// create the container if necessary
	if !bucketExists {
		err = CreateBucket(avereVfxt, a.AccountName, a.Container)
		if err != nil {
			return err
		}
	}
	return nil
}
