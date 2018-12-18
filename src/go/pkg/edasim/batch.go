package edasim

import (
	"fmt"
	"hash/fnv"
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
