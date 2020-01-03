// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package checkpoint

import (
	"encoding/json"
	"fmt"
	"path"
	"strings"

	"github.com/Azure/Avere/src/go/pkg/file"
	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/Avere/src/go/pkg/random"
)

// CheckpointFile represents a checkpoint file
type CheckpointFile struct {
	Name string
	PaddedString   string
}

// InitializeCheckpointFile sets the unique name of the job configuration and the batch name
func InitializeCheckpointFile(name string) *CheckpointFile {
	return &CheckpointFile{
		Name: name,
	}
}

// ReadCheckpointFile reads a job config file from disk
func ReadCheckpointFile(reader *file.ReaderWriter, filename string) (*CheckpointFile, error) {
	log.Debug.Printf("[ReadCheckpointFile %s", filename)
	defer log.Debug.Printf("ReadCheckpointFile %s]", filename)
	uniqueName, runName := GetCheckpointNameParts(filename)
	byteValue, err := reader.ReadFile(filename, uniqueName, runName)
	if err != nil {
		return nil, err
	}

	var result CheckpointFile
	if err := json.Unmarshal([]byte(byteValue), &result); err != nil {
		return nil, err
	}

	// clear the padded string for GC
	result.PaddedString = ""
	return &result, nil
}

// WriteJobConfigFile writes the job configuration file to disk, padding it so it makes the necessary size
func (c *CheckpointFile) WriteCheckpointFile(writer *file.ReaderWriter, filepath string, fileSizeBytes int) (string, error) {
	filename := path.Join(filepath, c.getCheckpointFileName())
	
	log.Debug.Printf("[WriteCheckpointFile(%s)", filename)
	defer log.Debug.Printf("WriteCheckpointFile(%s)]", filename)
	// learn the size of the current object
	data, err := json.Marshal(c)
	if err != nil {
		return "", err
	}

	// pad and re-martial to match the bytes
	padLength := (fileSizeBytes) - len(data)
	if padLength > 0 {
		c.PaddedString = random.RandStringRunesUltraFast(padLength)
		data, err = json.Marshal(c)
		if err != nil {
			return "", err
		}
	}

	uniqueName, runName := GetCheckpointNameParts(filename)
	if err := writer.WriteFile(filename, []byte(data), uniqueName, runName); err != nil {
		return "", err
	}

	return filename, nil
}

func (c *CheckpointFile) getCheckpointFileName() string {
	return fmt.Sprintf("%s.cp", c.Name)
}

// GetCheckpointName returns the checkpoint name, which is just the parent directory
func GetCheckpointName(fullFilePath string) string {
	return path.Base(path.Dir(fullFilePath))
}

// GetCheckpointNameParts generates the parts of the batch name
func GetCheckpointNameParts(fullFilePath string) (string, string) {
	parts := strings.Split(GetCheckpointName(fullFilePath), "-")
	if len(parts) > 1 {
		return parts[0], parts[1]
	} else if len(parts) > 0 {
		log.Error.Printf("CheckpointName did not parse correctly '%s'", GetCheckpointName(fullFilePath))
		return "", parts[0]
	} else {
		log.Error.Printf("CheckpointName did not parse correctly '%s'", GetCheckpointName(fullFilePath))
		return "", ""
	}
}

// GenerateCheckpointName generates a checkpoint name from unique name and frame name
func GenerateCheckpointName(uniqueName string, frameName string) string {
	return fmt.Sprintf("%s-%s", uniqueName, frameName)
}