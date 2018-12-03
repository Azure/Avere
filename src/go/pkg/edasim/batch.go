package edasim

import (
	"fmt"
	"path"
	"time"
)

// GetBatchName returns the batch name, which is just the parent directory
func GetBatchName(fullFilePath string) string {
	return path.Base(path.Dir(fullFilePath))
}

// GenerateBatchName generates a batchname based on time
func GenerateBatchName(jobCount int) string {
	t := time.Now()
	return fmt.Sprintf("job-%02d-%02d-%02d-%02d%02d%02d-%d", t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), jobCount)
}
