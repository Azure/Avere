package file

import (
	"encoding/json"
	"fmt"
	"time"
)

const (
	// ReadOperation represents read file
	ReadOperation = "read"
	// WriteOperation represents write file
	WriteOperation = "write"
	// NoBytesReadWritten means that no bytes were read or written
	NoBytesReadWritten = -1
	// NoDuration means that no duration was recorded
	NoDuration = time.Duration(-1)
)

// Operation represents the type of file io operation
type Operation string

// IOStatistics provides statistics on the file
type IOStatistics struct {
	StartTime       time.Time
	BatchName       string
	Label           string
	Operation       Operation
	CreateTimeNS    time.Duration
	CloseTimeNS     time.Duration
	ReadWriteTimeNS time.Duration
	ReadWriteBytes  int
	IsSuccess       bool
	FailureMessage  string
}

// InitializeIOStatistics initializes the IO Statistics
func InitializeIOStatistics(
	startTime time.Time,
	batchName string,
	label string,
	operation Operation,
	createTimeNS time.Duration,
	closeTimeNS time.Duration,
	readWriteTimeNS time.Duration,
	readWriteBytes int,
	err error) *IOStatistics {
	failureMessage := ""
	if err != nil {
		failureMessage = fmt.Sprintf("%v", err)
	}
	return &IOStatistics{
		StartTime:       startTime,
		BatchName:       batchName,
		Label:           label,
		Operation:       operation,
		CreateTimeNS:    createTimeNS,
		CloseTimeNS:     closeTimeNS,
		ReadWriteTimeNS: readWriteTimeNS,
		ReadWriteBytes:  readWriteBytes,
		IsSuccess:       err == nil,
		FailureMessage:  failureMessage,
	}
}

// InitializeIOStatisticsFromString initializes the object from a json string
func InitializeIOStatisticsFromString(jsonString string) (*IOStatistics, error) {
	var result IOStatistics
	if err := json.Unmarshal([]byte(jsonString), &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// GetJSON returns the JSON representation of the object
func (i *IOStatistics) GetJSON() ([]byte, error) {
	data, err := json.Marshal(i)
	if err != nil {
		return nil, err
	}
	return data, nil
}

// GetCategoryKey returns a key to represent label and operation
func (i *IOStatistics) GetCategoryKey() string {
	return fmt.Sprintf("%s.%s", i.Label, i.Operation)
}

// CSVHeader returns the CSV header
func (i *IOStatistics) CSVHeader() []string {
	header := []string{}
	header = append(header, "Date")
	header = append(header, "BatchName")
	header = append(header, "Label")
	header = append(header, "Operation")
	header = append(header, "CreateTimeNS")
	header = append(header, "CloseTimeNS")
	header = append(header, "ReadWriteTimeNS")
	header = append(header, "ReadWriteBytes")
	header = append(header, "IsSuccess")
	header = append(header, "FailureMessage")
	return header
}

// ToStringArray returns a csv formatted string
func (i *IOStatistics) ToStringArray() []string {
	row := []string{}
	//row = append(row, i.StartTime.String())
	row = append(row, i.StartTime.Format("2006-01-02 15:04:05.0000000"))
	row = append(row, i.BatchName)
	row = append(row, i.Label)
	row = append(row, string(i.Operation))
	row = append(row, fmt.Sprintf("%d", i.CreateTimeNS))
	row = append(row, fmt.Sprintf("%d", i.CloseTimeNS))
	row = append(row, fmt.Sprintf("%d", i.ReadWriteTimeNS))
	row = append(row, fmt.Sprintf("%d", i.ReadWriteBytes))
	row = append(row, fmt.Sprintf("%v", i.IsSuccess))
	row = append(row, i.FailureMessage)
	return row
}
