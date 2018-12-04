package log

import (
	"io"
	"io/ioutil"
	l "log"
	"os"
)

// this package is inspired by article https://www.ardanlabs.com/blog/2013/11/using-log-package-in-go.html

var (
	// Debug is used for debug statements and useful for debugging
	Debug *l.Logger
	// Info is used for general statements and useful for information logs
	Info *l.Logger
	// Warning is used for warning statements and useful for warning logs
	Warning *l.Logger
	// Error is used for error statements and useful for error logs
	Error *l.Logger
)

const (
	debugPrefix   = "DEBUG: "
	infoPrefix    = "INFO: "
	warningPrefix = "WARNING: "
	errorPrefix   = "ERROR: "
	defaultFlags  = l.Ldate | l.Ltime | l.Lmicroseconds | l.Llongfile | l.LUTC
)

func init() {
	initloggers(ioutil.Discard, os.Stdout, os.Stdout, os.Stderr)
}

func initloggers(
	traceHandle io.Writer,
	infoHandle io.Writer,
	warningHandle io.Writer,
	errorHandle io.Writer) {
	Debug = l.New(traceHandle, debugPrefix, defaultFlags)
	Info = l.New(infoHandle, infoPrefix, defaultFlags)
	Warning = l.New(warningHandle, warningPrefix, defaultFlags)
	Error = l.New(errorHandle, errorPrefix, defaultFlags)
}

// EnableDebugging enables all debug logs to be written to stdout
func EnableDebugging() {
	initloggers(os.Stdout, os.Stdout, os.Stdout, os.Stderr)
}
