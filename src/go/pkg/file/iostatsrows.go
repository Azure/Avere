package file

import (
	"encoding/csv"
	"fmt"
	"os"
	"sort"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/Avere/src/go/pkg/stats"
)

const (
	fileOpenTimeNSFileOp  = "FileOpenTimeNS"
	fileCloseTimeNSFileOp = "FileCloseTimeNS"
	ioTimeNSFileOp        = "IOTimeNS"
	ioBytesFileOp         = "IOBytes"
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

// GetRows returns the rows
func (i *IOStatsRows) GetRows() []*IOStatistics {
	return i.ioStatistics
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
	header = append(header, "Duration")
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
	batchName := i.ioStatistics[0].RunName
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

	lessFileOpenTimeNS := func(x, y int) bool { return i.ioStatistics[x].FileOpenTimeNS < i.ioStatistics[y].FileOpenTimeNS }
	i.WriteSummaryRow(writer, batchName, label, sampleSize, percentSuccess, percentileArray, fileOpenTimeNSFileOp, lessFileOpenTimeNS)
	lessFileCloseTimeNS := func(x, y int) bool { return i.ioStatistics[x].FileCloseTimeNS < i.ioStatistics[y].FileCloseTimeNS }
	i.WriteSummaryRow(writer, batchName, label, sampleSize, percentSuccess, percentileArray, fileCloseTimeNSFileOp, lessFileCloseTimeNS)
	lessIOTimeNS := func(x, y int) bool { return i.ioStatistics[x].IOTimeNS < i.ioStatistics[y].IOTimeNS }
	i.WriteSummaryRow(writer, batchName, label, sampleSize, percentSuccess, percentileArray, ioTimeNSFileOp, lessIOTimeNS)
	lessIOBytes := func(x, y int) bool { return i.ioStatistics[x].IOBytes < i.ioStatistics[y].IOBytes }
	i.WriteSummaryRow(writer, batchName, label, sampleSize, percentSuccess, percentileArray, ioBytesFileOp, lessIOBytes)
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

	// get the start / finish time
	lessStartTime := func(x, y int) bool { return i.ioStatistics[y].StartTime.After(i.ioStatistics[x].StartTime) }
	sort.Slice(i.ioStatistics, lessStartTime)
	firstRecordTime := i.ioStatistics[0].StartTime
	lastRecordTime := i.ioStatistics[len(i.ioStatistics)-1].StartTime
	diffTime := lastRecordTime.Sub(firstRecordTime)

	sort.Slice(i.ioStatistics, less)
	row := []string{}
	row = append(row, batchName)
	row = append(row, fmt.Sprintf("%v", diffTime))
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
	case fileOpenTimeNSFileOp:
		return fmt.Sprintf("%d", i.ioStatistics[p].FileOpenTimeNS/(1000*1000))
	case fileCloseTimeNSFileOp:
		return fmt.Sprintf("%d", i.ioStatistics[p].FileCloseTimeNS/(1000*1000))
	case ioTimeNSFileOp:
		return fmt.Sprintf("%d", i.ioStatistics[p].IOTimeNS/(1000*1000))
	case ioBytesFileOp:
		return fmt.Sprintf("%d", i.ioStatistics[p].IOBytes)
	default:
		log.Error.Printf("getPercentileValue: Should never arrive here, panic!")
		panic("getPercentileValue: Should never arrive here")
	}
}
