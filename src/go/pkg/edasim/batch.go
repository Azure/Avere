// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package edasim

import (
	"fmt"
	"hash/fnv"
	"path"
	"strings"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

// GetBatchName returns the batch name, which is just the parent directory
func GetBatchName(fullFilePath string) string {
	return path.Base(path.Dir(fullFilePath))
}

// GetBatchNamePartsFromJobRun generates the parts of the batch name
func GetBatchNamePartsFromJobRun(fullFilePath string) (string, string) {
	batchName := GetBatchName(fullFilePath)
	parts := strings.Split(GetBatchName(fullFilePath), "-")
	if len(parts) > 1 {
		return parts[0], parts[1]
	} else if len(parts) > 0 {
		log.Error.Printf("BatchName did not parse correctly %s", batchName)
		return "", parts[0]
	} else {
		log.Error.Printf("BatchName did not parse correctly %s", batchName)
		return "", ""
	}
}

// GenerateBatchNameFromJobRun generates a batch name from unique name and job run name and batch id
func GenerateBatchNameFromJobRun(uniqueName string, jobRunName string, batchid int) string {
	return fmt.Sprintf("%s-%s-%d", uniqueName, jobRunName, batchid)
}

// GenerateBatchName generates a batchname based on time
func GenerateBatchName(jobCount int) string {
	t := time.Now()
	uniqueStr := fmt.Sprintf("%02d-%02d-%02d-%02d%02d%02d-%d-%d", t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), t.Nanosecond(), jobCount)

	// generate a hashcode of the string
	h := fnv.New32a()
	h.Write([]byte(uniqueStr))

	return fmt.Sprintf("%d", h.Sum32())
}

// GenerateBatchName2 generates a batchname based on time
func GenerateBatchName2(jobCount int) string {
	t := time.Now()
	return fmt.Sprintf("job-%02d-%02d-%02d-%02d%02d%02d-%d", t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), jobCount)
}
