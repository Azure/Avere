// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package checkpoint

import (
	"fmt"
	"path"
	"strings"

	"github.com/Azure/Avere/src/go/pkg/file"
	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/Avere/src/go/pkg/random"
)

// CheckpointFile represents a checkpoint file
type CheckpointFile struct {
	Name    string
	Payload []byte
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
	name := GetName(filename)
	byteValue, err := reader.ReadFile(filename, uniqueName, runName)
	if err != nil {
		return nil, err
	}

	return &CheckpointFile{
		Name:    name,
		Payload: byteValue,
	}, nil
}

// WriteJobConfigFile writes the job configuration file to disk, padding it so it makes the necessary size
func (c *CheckpointFile) WriteCheckpointFile(writer *file.ReaderWriter, filepath string, fileSizeBytes int) (string, error) {
	filename := path.Join(filepath, c.getCheckpointFileName())
	uniqueName, runName := GetCheckpointNameParts(filename)

	log.Debug.Printf("[WriteCheckpointFile(%s)", filename)
	defer log.Debug.Printf("WriteCheckpointFile(%s)]", filename)

	if fileSizeBytes > 0 {
		c.Payload = random.RandStringRunesUltraFastBytesParallel(fileSizeBytes)
	}

	if err := writer.WriteFile(filename, c.Payload, uniqueName, runName); err != nil {
		return "", err
	}

	return filename, nil
}

func (c *CheckpointFile) getCheckpointFileName() string {
	return fmt.Sprintf("%s.cp", c.Name)
}

// return the filename
func GetName(fullFilePath string) string {
	fn := path.Base(fullFilePath)
	return strings.TrimSuffix(fn, path.Ext(fn))
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
