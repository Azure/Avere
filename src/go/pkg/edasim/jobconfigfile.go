package edasim

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path"

	"github.com/azure/avere/src/go/pkg/random"
)

// JobConfigFile represents a job configuration file
type JobConfigFile struct {
	Name           string
	BatchName      string
	IsCompleteFile bool
	PaddedString   string
}

// InitializeJobConfigFile sets the unique name of the job configuration and the batch name
func InitializeJobConfigFile(name string, batchName string) *JobConfigFile {
	return initializeJobFile(name, batchName, false)
}

// InitializeJobCompleteFile sets the unique name of the job configuration and the batch name and is used to signify job completion
func InitializeJobCompleteFile(name string, batchName string) *JobConfigFile {
	return initializeJobFile(name, batchName, true)
}

func initializeJobFile(name string, batchName string, isCompleteFile bool) *JobConfigFile {
	return &JobConfigFile{
		Name:           name,
		BatchName:      batchName,
		IsCompleteFile: isCompleteFile,
	}
}

// ReadJobConfigFile reads a job config file from disk
func ReadJobConfigFile(filename string) (*JobConfigFile, error) {
	// Open our jsonFile
	jsonFile, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer jsonFile.Close()

	byteValue, err := ioutil.ReadAll(jsonFile)
	if err != nil {
		return nil, err
	}

	var result JobConfigFile
	if err := json.Unmarshal([]byte(byteValue), &result); err != nil {
		return nil, err
	}

	// clear the padded string for GC
	result.PaddedString = ""
	return &result, nil
}

// WriteJobConfigFile writes the job configuration file to disk, padding it so it makes the necessary size
func (j *JobConfigFile) WriteJobConfigFile(filepath string, fileSize int) (string, error) {
	// learn the size of the current object
	data, err := json.Marshal(j)
	if err != nil {
		return "", err
	}

	// pad and re-martial to match the bytes
	padLength := (KB * 384) - len(data)
	if padLength > 0 {
		j.PaddedString = random.RandStringRunes(padLength)
		data, err = json.Marshal(j)
		if err != nil {
			return "", err
		}
	}

	filename := ""
	if j.IsCompleteFile {
		filename = path.Join(filepath, j.getJobConfigName())
	} else {
		filename = path.Join(filepath, j.getJobConfigCompleteName())
	}

	// write the file
	f, err := os.Create(filename)
	if err != nil {
		return "", err
	}

	defer f.Close()

	// write the padded file to disk
	if _, err = f.Write([]byte(data)); err != nil {
		return "", err
	}

	return filename, nil
}

func (j *JobConfigFile) getJobConfigName() string {
	return fmt.Sprintf("%s.job", j.Name)
}

func (j *JobConfigFile) getJobConfigCompleteName() string {
	return fmt.Sprintf("%s.complete", j.getJobConfigName())
}
