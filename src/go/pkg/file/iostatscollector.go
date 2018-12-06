package file

import (
	"encoding/csv"
	"fmt"
	"os"
	"path"
	"sync"

	"github.com/Azure/Avere/src/go/pkg/log"
)

// IOStatsCollector holds a collection of events
type IOStatsCollector struct {
	BatchMap map[string]map[string]*IOStatsRows
	mux      sync.Mutex
}

// InitializeIOStatsCollector initializes IOStatsCollector
func InitializeIOStatsCollector() *IOStatsCollector {
	return &IOStatsCollector{
		BatchMap: make(map[string]map[string]*IOStatsRows),
	}
}

// RecordEvent records the evenet
func (i *IOStatsCollector) RecordEvent(eMsg string) {
	i.mux.Lock()
	defer i.mux.Unlock()
	ios, err := InitializeIOStatisticsFromString(eMsg)
	if err != nil {
		log.Info.Printf("unable to parse iostatistics, error: %v", err)
		return
	}

	if _, ok := i.BatchMap[ios.BatchName]; !ok {
		i.BatchMap[ios.BatchName] = make(map[string]*IOStatsRows)
	}

	categoryKey := ios.GetCategoryKey()

	if _, ok := i.BatchMap[ios.BatchName][categoryKey]; !ok {
		i.BatchMap[ios.BatchName][categoryKey] = InitializeIOStatsRows()
	}

	i.BatchMap[ios.BatchName][categoryKey].AddIOStats(ios)
}

// WriteRAWFiles writes out all the files
func (i *IOStatsCollector) WriteRAWFiles(statsPath string) {
	i.mux.Lock()
	defer i.mux.Unlock()
	for k, batch := range i.BatchMap {
		batchDir := path.Join(statsPath, k)

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
func (i *IOStatsCollector) WriteBatchSummaryFiles(statsPath string) {
	i.mux.Lock()
	defer i.mux.Unlock()
	for k, batch := range i.BatchMap {
		batchDir := path.Join(statsPath, k)

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
