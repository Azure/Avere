package main

import (
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net"
	"os"
	"os/signal"
	"path"
	"path/filepath"
	"regexp"
	"sync"
	"time"
)

const (
	DefaultFileFilter = "*"
	DefaultReadBytes  = 21383
	timeBetweenPrints = time.Duration(1) * time.Second
	tick              = time.Duration(10) * time.Millisecond // 10ms
)

var matchSMB = regexp.MustCompile(`^\\\\([^\\]*)(\\.*)$`)

func isCancelled(ctx context.Context) bool {
	select {
	case <-ctx.Done():
		return true
	default:
		return false
	}
}

////////////////////////////////////////////////////////////////
// logging
////////////////////////////////////////////////////////////////

// logging inspired by article https://www.ardanlabs.com/blog/2013/11/using-log-package-in-go.html

var (
	// Info is used for general statements and useful for information logs
	Info *log.Logger
	// Error is used for error statements and useful for error logs
	Error *log.Logger
)

const (
	infoPrefix   = "INFO: "
	errorPrefix  = "ERROR: "
	defaultFlags = log.Ldate | log.Ltime | log.Lmicroseconds | log.Lshortfile | log.LUTC
)

func init() {
	initloggers(os.Stdout, os.Stderr)
}

func initloggers(
	infoHandle io.Writer,
	errorHandle io.Writer) {
	Info = log.New(infoHandle, infoPrefix, defaultFlags)
	Error = log.New(errorHandle, errorPrefix, defaultFlags)
}

////////////////////////////////////////////////////////////////
// stats collector
////////////////////////////////////////////////////////////////

type StatsCollector struct {
	mux                  sync.Mutex
	FileReadCount        int
	FileReadFailureCount int
	DirReadCount         int
	DirReadFailureCount  int
	RunningThreads       int
}

func InitializeStatsCollector() *StatsCollector {
	return &StatsCollector{}
}

func (s *StatsCollector) RunStatsPrinter(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	defer syncWaitGroup.Done()
	Info.Printf("[RunStatsPrinter")
	defer Info.Printf("RunStatsPrinter]")

	lastPrintTime := time.Now().Add(-timeBetweenPrints)
	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if time.Since(lastPrintTime) > timeBetweenPrints {
				lastPrintTime = time.Now()
				s.PrintStats()
			}
		}
	}
}

func (s *StatsCollector) PrintStats() {
	s.mux.Lock()
	defer s.mux.Unlock()

	fmt.Print("\r")
	fmt.Printf("\rfiles processed: %d, directories processed: %d, walkers: %d", s.FileReadCount, s.DirReadCount, s.RunningThreads)
}

func (s *StatsCollector) PrintSummary() {
	s.mux.Lock()
	defer s.mux.Unlock()
	fmt.Printf("\n")
	fmt.Printf("Summary\n")
	fmt.Printf("=========\n")
	fmt.Printf("FileReadCount       : %d\n", s.FileReadCount)
	fmt.Printf("FileReadFailureCount: %d\n", s.FileReadFailureCount)
	fmt.Printf("DirReadCount        : %d\n", s.DirReadCount)
	fmt.Printf("DirReadFailureCount : %d\n", s.DirReadFailureCount)
}

func (s *StatsCollector) RunningThreadIncr() {
	s.mux.Lock()
	defer s.mux.Unlock()
	s.RunningThreads++
}

func (s *StatsCollector) RunningThreadDecr() {
	s.mux.Lock()
	defer s.mux.Unlock()
	s.RunningThreads--
}

func (s *StatsCollector) GetRunningThreads() int {
	s.mux.Lock()
	defer s.mux.Unlock()
	return s.RunningThreads
}

func (s *StatsCollector) IncrFileReadCount() {
	s.mux.Lock()
	defer s.mux.Unlock()
	s.FileReadCount++
}

func (s *StatsCollector) IncrFileReadFailureCount() {
	s.mux.Lock()
	defer s.mux.Unlock()
	s.FileReadFailureCount++
}

func (s *StatsCollector) IncrDirReadCount() {
	s.mux.Lock()
	defer s.mux.Unlock()
	s.DirReadCount++
}

func (s *StatsCollector) IncrDirReadFailureCount() {
	s.mux.Lock()
	defer s.mux.Unlock()
	s.DirReadFailureCount++
}

////////////////////////////////////////////////////////////////
// walker
////////////////////////////////////////////////////////////////

type Walker struct {
	StatsCollector *StatsCollector
	Smbpath        string
	FileFilter     string
}

func InitializeWalker(statsCollector *StatsCollector, smbPath string, fileFilter string) *Walker {
	return &Walker{
		StatsCollector: statsCollector,
		Smbpath:        smbPath,
		FileFilter:     fileFilter,
	}
}

func (w *Walker) RunWalker(ctx context.Context, syncWaitGroup *sync.WaitGroup) {
	w.StatsCollector.RunningThreadIncr()
	defer w.StatsCollector.RunningThreadDecr()

	defer syncWaitGroup.Done()
	Info.Printf("[Walker %s", w.Smbpath)
	defer Info.Printf("Walker %s]", w.Smbpath)

	buffer := make([]byte, DefaultReadBytes)
	folderSlice := []string{w.Smbpath}
	for len(folderSlice) > 0 {
		select {
		case <-ctx.Done():
			return
		default:
			folder := folderSlice[len(folderSlice)-1]
			folderSlice[len(folderSlice)-1] = ""
			folderSlice = folderSlice[:len(folderSlice)-1]

			dirEntries, err := ioutil.ReadDir(folder)
			if err != nil {
				Error.Printf("error encountered reading directory '%s': %v", folder, err)
				continue
			}
			for _, dirEntry := range dirEntries {
				if isCancelled(ctx) {
					return
				}
				if dirEntry.IsDir() {
					folderSlice = append(folderSlice, path.Join(folder, dirEntry.Name()))
				} else {
					filename := path.Join(folder, dirEntry.Name())
					// only scan file if it matches filter
					if w.FileFilter != DefaultFileFilter {
						if isMatch, err := filepath.Match(w.FileFilter, filename); err != nil {
							Error.Printf("error matching filename %s: %v", filename, err)
							continue
						} else if !isMatch {
							continue
						}
					}
					// DEBUG
					Info.Printf("checking filename %s", filename)

					f, err := os.Open(filename)
					if err != nil {
						Error.Printf("error opening file %s: %v", filename, err)
						f.Close()
					}
					_, err = f.ReadAt(buffer, 0)
					if err != nil {
						if err != io.EOF {
							Error.Printf("error reading %d bytes of file %s: %v", DefaultReadBytes, filename, err)
						}
					}
					f.Close()
				}
			}
		}
	}
}

////////////////////////////////////////////////////////////////
// main - initialize variables and start the threads
////////////////////////////////////////////////////////////////

func usage() {
	fmt.Fprintf(os.Stderr, "usage: %s BASE_SMB_PATH [FILE_FILTER]\n", os.Args[0])
}

func InitializeVariables() ([]string, string) {
	if len(os.Args) <= 1 {
		fmt.Fprintf(os.Stderr, "ERROR: no base SMB PATH specified\n")
		usage()
		os.Exit(1)
	}
	baseSMBPath := os.Args[1]

	fileExtension := DefaultFileFilter
	if len(os.Args) > 2 {
		fileExtension = os.Args[2]
	}

	// validate the smb path
	matches := matchSMB.FindAllStringSubmatch(baseSMBPath, -1)
	if len(matches) == 0 || len(matches[0]) < 3 {
		fmt.Fprintf(os.Stderr, "ERROR: invalid SMB format, must be specified as \\\\fileaddress\\path\n")
		usage()
		os.Exit(2)
	}
	filer := matches[0][1]
	path := matches[0][2]

	ip := net.ParseIP(filer)
	if ip != nil {
		return []string{baseSMBPath}, fileExtension
	}

	// perform a dns lookup on the name to resolve all IP addresses
	ipAddresses, err := net.LookupIP(filer)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: invalid hostname, it doesn't resolve, and fails with error: %v\n", err)
		usage()
		os.Exit(3)
	}
	result := make([]string, 0, len(ipAddresses))
	for _, addr := range ipAddresses {
		fullPath := fmt.Sprintf("\\\\%s\\%s", addr.String(), path)
		Info.Printf("add path %s", fullPath)
		result = append(result, fullPath)
	}
	return result, fileExtension
}

func main() {
	// setup the shared context
	ctx, cancel := context.WithCancel(context.Background())

	targetSMBPaths, fileFilter := InitializeVariables()

	for _, s := range targetSMBPaths {
		Info.Printf("SMB Path: %s", s)
	}
	Info.Printf("fileextension filter: %s", fileFilter)

	// initialize the sync wait group
	syncWaitGroup := sync.WaitGroup{}
	syncWaitGroup.Add(1)
	// start the stats collector
	statsCollector := InitializeStatsCollector()
	go statsCollector.RunStatsPrinter(ctx, &syncWaitGroup)

	walkers := make([]*Walker, 0, len(targetSMBPaths))
	for _, s := range targetSMBPaths {
		walker := InitializeWalker(statsCollector, s, fileFilter)
		walkers = append(walkers, walker)
		go walker.RunWalker(ctx, &syncWaitGroup)
	}

	Info.Printf("wait for finish or ctrl-c")
	// wait on ctrl-c
	sigchan := make(chan os.Signal, 10)
	// catch all signals will cause cancellation when mounted, we need to
	// filter out better
	// signal.Notify(sigchan)
	signal.Notify(sigchan, os.Interrupt)

	lastPrintTime := time.Now().Add(-timeBetweenPrints)
	ticker := time.NewTicker(tick)
	defer ticker.Stop()
	stopped := false
	for !stopped {
		select {
		case <-sigchan:
			Info.Printf("Received ctrl-c, stopping walkers...")
			stopped = true
		case <-ticker.C:
			if time.Since(lastPrintTime) > timeBetweenPrints {
				lastPrintTime = time.Now()
				if statsCollector.GetRunningThreads() == 0 {
					Info.Printf("Threads finished running, stopping...")
					stopped = true
				}
			}
		}
	}
	cancel()

	Info.Printf("Waiting for all processes to finish")
	syncWaitGroup.Wait()

	Info.Printf("complete")
	statsCollector.PrintSummary()
}
