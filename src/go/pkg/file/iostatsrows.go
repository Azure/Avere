package file

import (
	"encoding/csv"
	"fmt"
	"os"
	"sort"

	"github.com/azure/avere/src/go/pkg/log"
	"github.com/azure/avere/src/go/pkg/stats"
)

const (
	createTimeNSFileOp    = "CreateTimeNS"
	closeTimeNSFileOp     = "CloseTimeNS"
	readWriteTimeNSFileOp = "ReadWriteTimeNS"
	readWriteBytesFileOp  = "ReadWriteBytes"
)

// IOStatsRows represents rows of statistics for the same category
type IOStatsRows struct {
	ioStatistics []*IOStatistics
}

// InitializeIOStatsRows initializes the io statistics rows structure
func InitializeIOStatsRows() *IOStatsRows {
	return &IOStatsRows{
		ioStatistics: []*IOStatistics{},
	}
}

// AddIOStats adds a statistics row
func (i *IOStatsRows) AddIOStats(ios *IOStatistics) {
	i.ioStatistics = append(i.ioStatistics, ios)
}

// GetRowCount returns the number of rows
func (i *IOStatsRows) GetRowCount() int {
	return len(i.ioStatistics)
}

// GetSuccessCount returns the count of successful rows
func (i *IOStatsRows) GetSuccessCount() int {
	successCount := len(i.ioStatistics)
	for _, record := range i.ioStatistics {
		if !record.IsSuccess {
			successCount--
		}
	}
	return successCount
}

// WriteCSVFile writes the rows out to a file
func (i *IOStatsRows) WriteCSVFile(filename string) {
	f, err := os.Create(filename)
	if err != nil {
		log.Error.Printf("error encountered creating file: %v", err)
		return
	}
	defer f.Close()

	w := csv.NewWriter(f)

	err = w.Write(i.ioStatistics[0].CSVHeader())
	if err != nil {
		log.Error.Printf("error encountered writing lines to file: %v", err)
	}

	for _, record := range i.ioStatistics {
		err := w.Write(record.ToStringArray())
		if err != nil {
			log.Error.Printf("error encountered writing lines to file: %v", err)
			break
		}
	}
	w.Flush()
	if w.Error() != nil {
		log.Error.Printf("error flushing file: %v", w.Error())
	}
}

// GetSummaryHeader returns the header for the summary file
func GetSummaryHeader() []string {
	header := []string{}
	header = append(header, "BatchName")
	header = append(header, "Label")
	header = append(header, "SampleSize")
	header = append(header, "%success")
	header = append(header, "FileOp")
	header = append(header, "P5")
	header = append(header, "P25")
	header = append(header, "P50")
	header = append(header, "P75")
	header = append(header, "P90")
	header = append(header, "P95")
	header = append(header, "P99")
	return header
}

// WriteSummaryLines writes summary rows for each label, for each operation of the batch
func (i *IOStatsRows) WriteSummaryLines(writer *csv.Writer) {
	if i.GetRowCount() == 0 {
		return
	}
	batchName := i.ioStatistics[0].BatchName
	label := i.ioStatistics[0].Label
	sampleSize := len(i.ioStatistics)
	percentSuccess := float64(i.GetSuccessCount()) / float64(sampleSize)
	percentileArray := []int{
		stats.GetPercentileIndex(float64(5), sampleSize),
		stats.GetPercentileIndex(float64(25), sampleSize),
		stats.GetPercentileIndex(float64(50), sampleSize),
		stats.GetPercentileIndex(float64(75), sampleSize),
		stats.GetPercentileIndex(float64(90), sampleSize),
		stats.GetPercentileIndex(float64(95), sampleSize),
		stats.GetPercentileIndex(float64(99), sampleSize),
	}

	lessCreateTimeNS := func(x, y int) bool { return i.ioStatistics[x].CreateTimeNS < i.ioStatistics[y].CreateTimeNS }
	i.WriteSummaryRow(writer, batchName, label, sampleSize, percentSuccess, percentileArray, createTimeNSFileOp, lessCreateTimeNS)
	lessCloseTimeNS := func(x, y int) bool { return i.ioStatistics[x].CloseTimeNS < i.ioStatistics[y].CloseTimeNS }
	i.WriteSummaryRow(writer, batchName, label, sampleSize, percentSuccess, percentileArray, closeTimeNSFileOp, lessCloseTimeNS)
	lessReadWriteTimeNS := func(x, y int) bool { return i.ioStatistics[x].ReadWriteTimeNS < i.ioStatistics[y].ReadWriteTimeNS }
	i.WriteSummaryRow(writer, batchName, label, sampleSize, percentSuccess, percentileArray, readWriteTimeNSFileOp, lessReadWriteTimeNS)
	lessReadWriteBytes := func(x, y int) bool { return i.ioStatistics[x].ReadWriteBytes < i.ioStatistics[y].ReadWriteBytes }
	i.WriteSummaryRow(writer, batchName, label, sampleSize, percentSuccess, percentileArray, readWriteBytesFileOp, lessReadWriteBytes)
}

// WriteSummaryRow writes a percentile summary row
func (i *IOStatsRows) WriteSummaryRow(
	writer *csv.Writer,
	batchName string,
	label string,
	sampleSize int,
	percentSuccess float64,
	percentileArray []int,
	fileOp string,
	less func(i, j int) bool) {

	sort.Slice(i.ioStatistics, less)
	row := []string{}
	row = append(row, batchName)
	row = append(row, label)
	row = append(row, fmt.Sprintf("%d", sampleSize))
	row = append(row, fmt.Sprintf("%f", percentSuccess))
	row = append(row, fileOp)
	for _, percentile := range percentileArray {
		row = append(row, i.getPercentileValue(percentile, fileOp))
	}

	if err := writer.Write(row); err != nil {
		log.Error.Printf("error writing summary lines: %v", err)
	}
}

func (i *IOStatsRows) getPercentileValue(p int, fileop string) string {
	switch fileop {
	case createTimeNSFileOp:
		return fmt.Sprintf("%d", i.ioStatistics[p].CreateTimeNS/(1000*1000))
	case closeTimeNSFileOp:
		return fmt.Sprintf("%d", i.ioStatistics[p].CloseTimeNS/(1000*1000))
	case readWriteTimeNSFileOp:
		return fmt.Sprintf("%d", i.ioStatistics[p].ReadWriteTimeNS/(1000*1000))
	case readWriteBytesFileOp:
		return fmt.Sprintf("%d", i.ioStatistics[p].ReadWriteBytes)
	default:
		log.Error.Printf("getPercentileValue: Should never arrive here, panic!")
		panic("getPercentileValue: Should never arrive here")
	}
}
