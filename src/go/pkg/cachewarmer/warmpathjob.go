// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"encoding/json"
	"fmt"
	"hash/fnv"
	"path"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

// WarmPathJob contains the information for a new job item
type WarmPathJob struct {
	WarmTargetMountAddresses []string
	WarmTargetExportPath string
	WarmTargetPath string
	JobMountAddress string
	JobExportPath string
	JobBasePath string
}

// InitializeWarmPathJob initializes the job submitter structure
func InitializeWarmPathJob(
	warmTargetMountAddresses []string,
	warmTargetExportPath string,
	warmTargetPath string,
	jobMountAddress string,
	jobExportPath string,
	jobBasePath string) *WarmPathJob {
	return &WarmPathJob{
		WarmTargetMountAddresses: warmTargetMountAddresses,
		WarmTargetExportPath: warmTargetExportPath,
		WarmTargetPath: warmTargetPath,
		JobMountAddress: jobMountAddress,
		JobExportPath: jobExportPath,
		JobBasePath: jobBasePath,
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

// WriteJob outputs a JSON file
func (j *WarmPathJob) WriteJob() error {
	// create the job path if not exists
	jobSubmitterPath, err := EnsureJobSubmitterPath(j.JobMountAddress, j.JobExportPath, j.JobBasePath)
	if err != nil {
		return fmt.Errorf("encountered error while ensuring path %s: %v", jobSubmitterPath, err)
	}

	// get the JSON output
	fileContents, err := j.GetWarmPathJobFileContents()
	if err != nil {
		return err
	}

	// write the file
	jobFile := j.GenerateWarmPathJobFilename(jobSubmitterPath)
	log.Debug.Printf("write warm job file %s", jobFile)
	if err := WriteFile(jobFile, fileContents) ; err != nil {
		return err
	}

	return nil
}

// GetWarmPathJobFileContents returns the contents of the file
func (j *WarmPathJob) GetWarmPathJobFileContents() (string, error) {
	data, err := json.Marshal(j)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// GenerateJobFilename generates a file name based on time, and the warm path
func  (j *WarmPathJob) GenerateWarmPathJobFilename(jobSubmitterPath string) string {
	// generate a hashcode of the string
	h := fnv.New32a()
	h.Write([]byte(j.WarmTargetPath))

	t := time.Now()
	return path.Join(jobSubmitterPath, fmt.Sprintf("%02d-%02d-%02d-%02d%02d%02d-%d.job", t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), h.Sum32()))
}

