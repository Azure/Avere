// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
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
	// Status is used for statistics collections and milestones
	Status *l.Logger
)

const (
	debugPrefix   = "DEBUG: "
	infoPrefix    = "INFO: "
	warningPrefix = "WARNING: "
	errorPrefix   = "ERROR: "
	statusPrefix  = "STATUS: "
	defaultFlags  = l.Ldate | l.Ltime | l.Lmicroseconds | l.Lshortfile | l.LUTC
)

func init() {
	initloggers(ioutil.Discard, os.Stdout, os.Stdout, os.Stderr, os.Stdout)
}

func initloggers(
	traceHandle io.Writer,
	infoHandle io.Writer,
	warningHandle io.Writer,
	errorHandle io.Writer,
	statusHandle io.Writer) {
	Debug = l.New(traceHandle, debugPrefix, defaultFlags)
	Info = l.New(infoHandle, infoPrefix, defaultFlags)
	Warning = l.New(warningHandle, warningPrefix, defaultFlags)
	Error = l.New(errorHandle, errorPrefix, defaultFlags)
	Status = l.New(statusHandle, statusPrefix, defaultFlags)
}

// EnableDebugging enables all debug logs to be written to stdout
func EnableDebugging() {
	initloggers(os.Stdout, os.Stdout, os.Stdout, os.Stderr, os.Stdout)
}
