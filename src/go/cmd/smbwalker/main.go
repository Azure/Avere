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
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	B = 1 << (10 * iota)
	KB
	MB
	GB
)

const (
	DefaultFileFilter      = "*"
	DefaultWalkersPerShare = 1
	DefaultReadBytes       = 21383
	timeBetweenPrints      = time.Duration(1) * time.Second
	tick                   = time.Duration(10) * time.Millisecond // 10ms
	ReadPageSize           = 10 * MB
	timeBetweenCancelCheck = time.Duration(100) * time.Millisecond  // 100ms
	timeBetweenStatusCheck = time.Duration(1000) * time.Millisecond // 1s
)

var matchSMB = regexp.MustCompile(`^\\\\([^\\]*)\\(.*)$`)

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
	FileOpenCount        int
	FileOpenFailureCount int
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
	fmt.Printf("FileOpenCount       : %d\n", s.FileOpenCount)
	fmt.Printf("FileOpenFailureCount: %d\n", s.FileOpenFailureCount)
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

func (s *StatsCollector) IncrFileOpenCount() {
	s.mux.Lock()
	defer s.mux.Unlock()
	s.FileOpenCount++
}

func (s *StatsCollector) IncrFileOpenFailureCount() {
	s.mux.Lock()
	defer s.mux.Unlock()
	s.FileOpenFailureCount++
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

func (w *Walker) RunWalker(ctx context.Context, syncWaitGroup *sync.WaitGroup, runForever bool) {
	w.StatsCollector.RunningThreadIncr()
	defer w.StatsCollector.RunningThreadDecr()

	defer syncWaitGroup.Done()
	Info.Printf("[Walker %s", w.Smbpath)
	defer Info.Printf("Walker %s]", w.Smbpath)

	for {
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
					w.StatsCollector.IncrDirReadFailureCount()
					continue
				}
				w.StatsCollector.IncrDirReadCount()
				for _, dirEntry := range dirEntries {
					if isCancelled(ctx) {
						return
					}
					if dirEntry.IsDir() {
						folderSlice = append(folderSlice, path.Join(folder, dirEntry.Name()))
					} else {
						// only scan file if it matches filter
						if w.FileFilter != DefaultFileFilter {
							if isMatch, err := filepath.Match(w.FileFilter, dirEntry.Name()); err != nil {
								Error.Printf("error matching filename %s: %v", dirEntry.Name(), err)
								continue
							} else if !isMatch {
								continue
							}
						}
						filename := path.Join(folder, dirEntry.Name())
						// DEBUG
						//Info.Printf("checking filename %s", filename)
						w.readFileFull(ctx, filename)
					}
				}
			}
		}
		if !runForever {
			break
		}
	}

}

func (w *Walker) readFileFull(ctx context.Context, filename string) {
	var readBytes int
	file, err := os.Open(filename)
	if err != nil {
		w.StatsCollector.IncrFileReadFailureCount()
		Error.Printf("error opening file %s: %v", filename, err)
		return
	}
	defer file.Close()
	w.StatsCollector.IncrFileOpenCount()
	buffer := make([]byte, ReadPageSize)
	lastCancelCheckTime := time.Now()
	lastStatusTime := time.Now()
	for {
		count, err := file.Read(buffer)
		readBytes += count
		if err != nil {
			if err != io.EOF {
				w.StatsCollector.IncrFileReadFailureCount()
				Error.Printf("error reading file %s: %v", filename, err)
			}
			w.StatsCollector.IncrFileReadCount()
			lastStatusTime = time.Now()
			Info.Printf("read %d bytes from filepath %s", readBytes, filename)
			return
		}
		// ensure no cancel
		if time.Since(lastCancelCheckTime) > timeBetweenCancelCheck {
			lastCancelCheckTime = time.Now()
			if isCancelled(ctx) {
				return
			}
		}
		if time.Since(lastStatusTime) > timeBetweenStatusCheck {
			lastStatusTime = time.Now()
			Info.Printf("reading %d bytes from large file %s", readBytes, filename)
		}
	}
}

////////////////////////////////////////////////////////////////
// main - initialize variables and start the threads
////////////////////////////////////////////////////////////////

func usage() {
	fmt.Fprintf(os.Stderr, "usage: %s BASE_SMB_PATH [WALKERS_PER_SHARE] [FILE_FILTER] [RUN_FOREVER(true|*false*)]\n", os.Args[0])
}

func InitializeVariables() ([]string, int, string, bool) {
	if len(os.Args) <= 1 {
		fmt.Fprintf(os.Stderr, "ERROR: no base SMB PATH specified\n")
		usage()
		os.Exit(1)
	}
	baseSMBPath := os.Args[1]
	baseSMBPath = strings.ReplaceAll(baseSMBPath, "/", "\\")
	baseSMBPath = strings.TrimSuffix(baseSMBPath, "\\")

	walkersPerShare := DefaultWalkersPerShare
	if len(os.Args) > 2 {
		if i, err := strconv.Atoi(os.Args[2]); err == nil {
			walkersPerShare = i
		} else {
			fmt.Fprintf(os.Stderr, "ERROR: incorrect value specified for walker count %s\n", os.Args[2])
			usage()
			os.Exit(4)
		}
	}

	fileExtension := DefaultFileFilter
	if len(os.Args) > 3 {
		fileExtension = os.Args[3]
	}

	runForever := false
	if len(os.Args) > 4 {
		runForever = (os.Args[4] == "true")
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
		return []string{baseSMBPath}, walkersPerShare, fileExtension, runForever
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
	return result, walkersPerShare, fileExtension, runForever
}

func main() {
	// setup the shared context
	ctx, cancel := context.WithCancel(context.Background())

	targetSMBPaths, walkersPerShare, fileFilter, runForever := InitializeVariables()

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

	walkers := make([]*Walker, 0, len(targetSMBPaths)*walkersPerShare)
	for i := 0; i < walkersPerShare; i++ {
		for _, s := range targetSMBPaths {
			walker := InitializeWalker(statsCollector, s, fileFilter)
			walkers = append(walkers, walker)
			syncWaitGroup.Add(1)
			go walker.RunWalker(ctx, &syncWaitGroup, runForever)
		}
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
