// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"encoding/json"
	"strings"

	"github.com/Azure/azure-storage-queue-go/azqueue"
)

// WarmPathJob contains the information for a new job item
type WarmPathJob struct {
	WarmTargetMountAddresses []string
	WarmTargetExportPath     string
	WarmTargetPath           string
	InclusionList            []string
	ExclusionList            []string
	queueMessageID           *azqueue.MessageID
	queuePopReceipt          *azqueue.PopReceipt
}

func (j *WarmPathJob) FileMatches(filename string) bool {
	return FileMatches(j.InclusionList, j.ExclusionList, filename)
}

// InitializeWarmPathJob initializes the job submitter structure
func InitializeWarmPathJob(
	warmTargetMountAddresses []string,
	warmTargetExportPath string,
	warmTargetPath string,
	inclusionCsv string,
	exclusionCsv string) *WarmPathJob {

	return &WarmPathJob{
		WarmTargetMountAddresses: warmTargetMountAddresses,
		WarmTargetExportPath:     warmTargetExportPath,
		WarmTargetPath:           warmTargetPath,
		InclusionList:            prepareCsvList(inclusionCsv),
		ExclusionList:            prepareCsvList(exclusionCsv),
	}
}

// InitializeWarmPathJobFromString reads warmPathJobContents
func InitializeWarmPathJobFromString(warmPathJobContents string) (*WarmPathJob, error) {
	var result WarmPathJob
	if err := json.Unmarshal([]byte(warmPathJobContents), &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// GetWarmPathJobFileContents returns the contents of the file
func (j *WarmPathJob) GetWarmPathJobFileContents() (string, error) {
	data, err := json.Marshal(j)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func (j *WarmPathJob) SetQueueMessageInfo(id *azqueue.MessageID, popReceipt *azqueue.PopReceipt) {
	j.queueMessageID = id
	j.queuePopReceipt = popReceipt
}

func (j *WarmPathJob) GetQueueMessageInfo() (*azqueue.MessageID, *azqueue.PopReceipt) {
	return j.queueMessageID, j.queuePopReceipt
}

func prepareCsvList(csv string) []string {
	result := []string{}
	for _, s := range strings.Split(csv, ",") {
		trim := strings.TrimSpace(s)
		if len(trim) > 0 {
			result = append(result, trim)
		}
	}
	return result
}
