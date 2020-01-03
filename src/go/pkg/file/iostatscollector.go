// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package file

import (
	"encoding/csv"
	"fmt"
	"os"
	"path"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

const (
	KB             = 1024
	MB             = KB * KB
	JobReaderLabel = "JobReader"
)

// IOStatsCollector holds a collection of events
type IOStatsCollector struct {
	UniqueName string
	// BatchMap maps the read and write operations
	BatchMap map[string]map[string]*IOStatsRows
	// IOMap maps the read and write operations
	IOMap    map[string]map[string]*IOStatsRows
	JobCount map[string]map[string]int
	mux      sync.Mutex
}

// InitializeIOStatsCollector initializes IOStatsCollector
func InitializeIOStatsCollector(uniqueName string) *IOStatsCollector {
	return &IOStatsCollector{
		UniqueName: uniqueName,
		BatchMap:   make(map[string]map[string]*IOStatsRows),
	}
}

// RecordEvent records the event
func (i *IOStatsCollector) RecordEvent(eMsg string) {
	i.mux.Lock()
	defer i.mux.Unlock()
	ios, err := InitializeIOStatisticsFromString(eMsg)
	if err != nil {
		log.Info.Printf("unable to parse iostatistics, error: %v", err)
		return
	}

	// record to batch map
	if _, ok := i.BatchMap[ios.RunName]; !ok {
		i.BatchMap[ios.RunName] = make(map[string]*IOStatsRows)
	}

	categoryKey := ios.GetCategoryKey()

	if _, ok := i.BatchMap[ios.RunName][categoryKey]; !ok {
		i.BatchMap[ios.RunName][categoryKey] = InitializeIOStatsRows()
	}

	i.BatchMap[ios.RunName][categoryKey].AddIOStats(ios)

	// record to IO Map

}

// WriteRAWFiles writes out all the files
func (i *IOStatsCollector) WriteRAWFiles(statsPath string, uniqueName string) {
	i.mux.Lock()
	defer i.mux.Unlock()
	for k, batch := range i.BatchMap {
		batchDir := path.Join(statsPath, fmt.Sprintf("%s-%s", uniqueName, k))

		log.Info.Printf("mkdir all %s", batchDir)
		os.MkdirAll(batchDir, os.ModePerm)

		for categoryName, categoryRows := range batch {
			if categoryRows.GetRowCount() == 0 {
				log.Error.Printf("there are no category rows empty, how did this object get created?")
				continue
			}
			filename := path.Join(batchDir, fmt.Sprintf("%s.csv", categoryName))
			categoryRows.WriteCSVFile(filename)
		}
	}
}

// WriteBatchSummaryFiles writes out a summary file for each batch run
func (i *IOStatsCollector) WriteBatchSummaryFiles(statsPath string, uniqueName string) {
	i.mux.Lock()
	defer i.mux.Unlock()
	for k, batch := range i.BatchMap {
		batchDir := path.Join(statsPath, fmt.Sprintf("%s-%s", uniqueName, k))

		log.Info.Printf("mkdir all %s", batchDir)
		os.MkdirAll(batchDir, os.ModePerm)

		summaryFilename := path.Join(batchDir, "summary.csv")
		sf, err := os.Create(summaryFilename)
		if err != nil {
			log.Error.Printf("error encountered creating file: %v", err)
			continue
		}
		sfw := csv.NewWriter(sf)
		err = sfw.Write(GetSummaryHeader())
		if err != nil {
			log.Error.Printf("error writing summary header: %v", err)
			continue
		}

		for _, categoryRows := range batch {
			if categoryRows.GetRowCount() == 0 {
				log.Error.Printf("there are no category rows empty, how did this object get created?")
				continue
			}
			categoryRows.WriteSummaryLines(sfw)
		}

		sfw.Flush()
		if sfw.Error() != nil {
			log.Error.Printf("error flushing summary file: %v", sfw.Error())
		}
		sf.Close()
	}
}

// WriteIOSummaryFiles writes out a summary file for each batch run
func (i *IOStatsCollector) WriteIOSummaryFiles(statsPath string, uniqueName string) {
	i.mux.Lock()
	defer i.mux.Unlock()

	header := []string{}
	header = append(header, "Operation")
	header = append(header, "Duration")
	header = append(header, "MB/s")
	header = append(header, "Total MB")
	header = append(header, "Total Ops")

	for k, batch := range i.BatchMap {
		batchDir := path.Join(statsPath, fmt.Sprintf("%s-%s", uniqueName, k))

		log.Info.Printf("mkdir all %s", batchDir)
		os.MkdirAll(batchDir, os.ModePerm)

		summaryFilename := path.Join(batchDir, "iosummary.csv")
		sf, err := os.Create(summaryFilename)
		if err != nil {
			log.Error.Printf("error encountered creating file: %v", err)
			continue
		}
		sfw := csv.NewWriter(sf)
		err = sfw.Write(header)
		if err != nil {
			log.Error.Printf("error writing summary header: %v", err)
			continue
		}

		// get io stats
		readMinTime := time.Now()
		readMaxTime := time.Time{}
		var readBytes int64
		var readOpCount int64
		writeMinTime := time.Now()
		writeMaxTime := time.Time{}
		var writeBytes int64
		var writeOpCount int64
		jobCount := 0
		for _, categoryRows := range batch {
			for _, row := range categoryRows.GetRows() {
				if jobCount == 0 {
					if row.Label == JobReaderLabel {
						jobCount = categoryRows.GetRowCount()
					}
				}
				if row.Operation == ReadOperation {
					if row.StartTime.Before(readMinTime) {
						readMinTime = row.StartTime
					}
					endTime := row.StartTime.Add(row.FileOpenTimeNS + row.FileCloseTimeNS + row.IOTimeNS)
					if readMaxTime.Before(endTime) {
						readMaxTime = endTime
					}
					readBytes += int64(row.IOBytes)
					readOpCount++
				} else if row.Operation == WriteOperation {
					if row.StartTime.Before(writeMinTime) {
						writeMinTime = row.StartTime
					}
					endTime := row.StartTime.Add(row.FileOpenTimeNS + row.FileCloseTimeNS + row.IOTimeNS)
					if writeMaxTime.Before(endTime) {
						writeMaxTime = endTime
					}
					writeBytes += int64(row.IOBytes)
					writeOpCount++
				}
			}
		}

		readRow := []string{}
		readRow = append(readRow, ReadOperation)
		duration := readMaxTime.Sub(readMinTime)
		readRow = append(readRow, fmt.Sprintf("%v", duration))
		readRow = append(readRow, fmt.Sprintf("%.2f", float64(readBytes/MB)/duration.Seconds()))
		readRow = append(readRow, fmt.Sprintf("%d", readBytes/MB))
		readRow = append(readRow, fmt.Sprintf("%d", readOpCount))

		err = sfw.Write(readRow)
		if err != nil {
			log.Error.Printf("error writing read row: %v", err)
			continue
		}

		writeRow := []string{}
		writeRow = append(writeRow, WriteOperation)
		duration = writeMaxTime.Sub(writeMinTime)
		writeRow = append(writeRow, fmt.Sprintf("%v", duration))
		writeRow = append(writeRow, fmt.Sprintf("%.2f", float64(writeBytes/MB)/duration.Seconds()))
		writeRow = append(writeRow, fmt.Sprintf("%d", writeBytes/MB))
		writeRow = append(writeRow, fmt.Sprintf("%d", writeOpCount))

		err = sfw.Write(writeRow)
		if err != nil {
			log.Error.Printf("error writing write row: %v", err)
			continue
		}

		sfw.Flush()
		if sfw.Error() != nil {
			log.Error.Printf("error flushing summary file: %v", sfw.Error())
		}

		// write the job count
		minTime := readMinTime
		if minTime.After(writeMinTime) {
			minTime = writeMinTime
		}
		maxTime := readMaxTime
		if maxTime.Before(readMaxTime) {
			maxTime = readMaxTime
		}
		jobDuration := maxTime.Sub(minTime)

		sf.WriteString("\n")
		sf.WriteString(fmt.Sprintf("total duration,%v\n", jobDuration))
		sf.WriteString(fmt.Sprintf("job count,%d\n", jobCount))
		sf.WriteString(fmt.Sprintf("Jobs/s,%.2f\n", float64(jobCount)/jobDuration.Seconds()))

		sf.Close()
	}
}
