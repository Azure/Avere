package file

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

const (
	// ReadOperation represents read file
	ReadOperation = "read"
	// WriteOperation represents write file
	WriteOperation = "write"
	// NoIOBytes means that no bytes were read or written
	NoIOBytes = -1
	// NoDuration means that no duration was recorded
	NoDuration = time.Duration(-1)
)

var hostname string

func init() {
	hostname = ""
	if h, err := os.Hostname(); err != nil {
		hostname = h
	} else {
		log.Error.Printf("error encountered getting hostname: %v", err)
	}
}

// Operation represents the type of file io operation
type Operation string

// IOStatistics provides statistics on the file
type IOStatistics struct {
	StartTime       time.Time
	BatchName       string
	Label           string
	Operation       Operation
	Path            string
	FileOpenTimeNS  time.Duration
	FileCloseTimeNS time.Duration
	IOTimeNS        time.Duration
	IOBytes         int
	IsSuccess       bool
	FailureMessage  string
}

// InitializeIOStatistics initializes the IO Statistics
func InitializeIOStatistics(
	startTime time.Time,
	batchName string,
	label string,
	operation Operation,
	path string,
	fileOpenTimeNS time.Duration,
	closeTimeNS time.Duration,
	ioTimeNS time.Duration,
	ioBytes int,
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
		Path:            path,
		FileOpenTimeNS:  fileOpenTimeNS,
		FileCloseTimeNS: closeTimeNS,
		IOTimeNS:        ioTimeNS,
		IOBytes:         ioBytes,
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
	header = append(header, "Hostname")
	header = append(header, "BatchName")
	header = append(header, "Label")
	header = append(header, "Operation")
	header = append(header, "Path")
	header = append(header, "FileOpenTimeNS")
	header = append(header, "FileCloseTimeNS")
	header = append(header, "IOTimeNS")
	header = append(header, "IOBytes")
	header = append(header, "IsSuccess")
	header = append(header, "FailureMessage")
	return header
}

// ToStringArray returns a csv formatted string
func (i *IOStatistics) ToStringArray() []string {
	row := []string{}
	//row = append(row, i.StartTime.String())
	row = append(row, i.StartTime.Format("2006-01-02 15:04:05.0000000"))
	row = append(row, hostname)
	row = append(row, i.BatchName)
	row = append(row, i.Label)
	row = append(row, string(i.Operation))
	row = append(row, i.Path)
	row = append(row, fmt.Sprintf("%d", i.FileOpenTimeNS))
	row = append(row, fmt.Sprintf("%d", i.FileCloseTimeNS))
	row = append(row, fmt.Sprintf("%d", i.IOTimeNS))
	row = append(row, fmt.Sprintf("%d", i.IOBytes))
	row = append(row, fmt.Sprintf("%v", i.IsSuccess))
	row = append(row, i.FailureMessage)
	return row
}
