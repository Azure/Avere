// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"encoding/json"
	"os"
	"strings"

	"github.com/Azure/azure-storage-queue-go/azqueue"
)

// WorkerJob contains the information for a worker job item
type WorkerJob struct {
	WarmTargetMountAddresses []string
	WarmTargetExportPath     string
	WarmTargetPath           string
	StartByte                int64
	StopByte                 int64
	ApplyFilter              bool
	StartFileFilter          string
	EndFileFilter            string
	InclusionList            []string
	ExclusionList            []string
	MaxFileSizeBytes         int64
	queueMessageID           azqueue.MessageID
	queuePopReceipt          azqueue.PopReceipt
}

func (j *WorkerJob) SetQueueMessageInfo(id azqueue.MessageID, popReceipt azqueue.PopReceipt) {
	j.queueMessageID = id
	j.queuePopReceipt = popReceipt
}

func (j *WorkerJob) GetQueueMessageInfo() (azqueue.MessageID, azqueue.PopReceipt) {
	return j.queueMessageID, j.queuePopReceipt
}

// InitializeWorkerJob initializes the worker job structure
func InitializeWorkerJob(
	warmTargetMountAddresses []string,
	warmTargetExportPath string,
	warmTargetPath string,
	inclusionList []string,
	exclusionList []string,
	maxFileSizeBytes int64) *WorkerJob {
	return &WorkerJob{
		WarmTargetMountAddresses: warmTargetMountAddresses,
		WarmTargetExportPath:     warmTargetExportPath,
		WarmTargetPath:           warmTargetPath,
		StartByte:                allFilesOrBytes,
		StopByte:                 allFilesOrBytes,
		ApplyFilter:              false,
		StartFileFilter:          "",
		EndFileFilter:            "",
		InclusionList:            inclusionList,
		ExclusionList:            exclusionList,
		MaxFileSizeBytes:         maxFileSizeBytes,
	}
}

// InitializeWorkerJob initializes the worker job structure
func InitializeWorkerJobForLargeFile(
	warmTargetMountAddresses []string,
	warmTargetExportPath string,
	warmTargetPath string,
	startByte int64,
	stopByte int64,
	inclusionList []string,
	exclusionList []string,
	maxFileSizeBytes int64) *WorkerJob {
	return &WorkerJob{
		WarmTargetMountAddresses: warmTargetMountAddresses,
		WarmTargetExportPath:     warmTargetExportPath,
		WarmTargetPath:           warmTargetPath,
		StartByte:                startByte,
		StopByte:                 stopByte,
		ApplyFilter:              false,
		StartFileFilter:          "",
		EndFileFilter:            "",
		InclusionList:            inclusionList,
		ExclusionList:            exclusionList,
		MaxFileSizeBytes:         maxFileSizeBytes,
	}
}

// InitializeWorkerJobWithFilter initializes the worker job structure
func InitializeWorkerJobWithFilter(
	warmTargetMountAddresses []string,
	warmTargetExportPath string,
	warmTargetPath string,
	startFileFilter string,
	endFileFilter string,
	inclusionList []string,
	exclusionList []string,
	maxFileSizeBytes int64) *WorkerJob {
	return &WorkerJob{
		WarmTargetMountAddresses: warmTargetMountAddresses,
		WarmTargetExportPath:     warmTargetExportPath,
		WarmTargetPath:           warmTargetPath,
		StartByte:                allFilesOrBytes,
		StopByte:                 allFilesOrBytes,
		ApplyFilter:              true,
		StartFileFilter:          startFileFilter,
		EndFileFilter:            endFileFilter,
		InclusionList:            inclusionList,
		ExclusionList:            exclusionList,
		MaxFileSizeBytes:         maxFileSizeBytes,
	}
}

// InitializeWorkerJobFromString reads warmPathJobContents
func InitializeWorkerJobFromString(workerJobContents string) (*WorkerJob, error) {
	var result WorkerJob
	if err := json.Unmarshal([]byte(workerJobContents), &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// GetWorkerJobFileContents returns the contents of the file
func (j *WorkerJob) GetWorkerJobFileContents() (string, error) {
	data, err := json.Marshal(j)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func (j *WorkerJob) FilterFiles(dirEntries []os.FileInfo) []string {
	filteredFileNames := make([]string, 0, len(dirEntries))

	for _, dirEntry := range dirEntries {
		if !dirEntry.IsDir() {
			filename := dirEntry.Name()
			if j.ApplyFilter == false {
				filteredFileNames = append(filteredFileNames, filename)
			} else {
				compareStart := strings.Compare(filename, j.StartFileFilter)
				if compareStart == 0 || (compareStart > 0 && strings.Compare(filename, j.EndFileFilter) <= 0) {
					if FileMatches(j.InclusionList, j.ExclusionList, j.MaxFileSizeBytes, filename, dirEntry.Size()) {
						filteredFileNames = append(filteredFileNames, filename)
					}
				}
			}
		}
	}

	return filteredFileNames
}
