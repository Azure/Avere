package edasim

import (
	"encoding/json"

	"github.com/Azure/Avere/src/go/pkg/log"
)

// EdasimFile breaks an edasimfile into three parts
type EdasimFile struct {
	// the job run details
	MountPath string
	FullPath  string
	MountParity bool
}

// InitializeEdasimFileFromString reads a edasimFileString from json string
func InitializeEdasimFileFromString(edasimFileString string) (*EdasimFile, error) {
	log.Debug.Printf("[InitializeEdasimFileFromString ")
	defer log.Debug.Printf("InitializeEdasimFileFromString ]")

	var result EdasimFile
	if err := json.Unmarshal([]byte(edasimFileString), &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// GetEdasimFileString returns the JSON representation of the edasimFileString
func (e *EdasimFile) GetEdasimFileString() (string, error) {
	log.Debug.Printf("[GetEdasimFileString()")
	defer log.Debug.Printf("GetEdasimFileString()]")

	data, err := json.Marshal(e)
	if err != nil {
		return "", err
	}
	return string(data), nil
}
