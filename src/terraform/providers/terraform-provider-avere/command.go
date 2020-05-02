// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bytes"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"sync"
)

func BashCommand(cmdstr string) (bytes.Buffer, bytes.Buffer, error) {
	// command execution technique modified from examples of https://blog.kowalczyk.info/article/wOYk/advanced-command-execution-in-go-with-osexec.html
	var stdoutBuf, stderrBuf bytes.Buffer

	// always run the command from the home directory
	cmd := exec.Command("/bin/bash", "-c", fmt.Sprintf("cd $HOME && %s", cmdstr))
	stdoutIn, err := cmd.StdoutPipe()
	if err != nil {
		return stdoutBuf, stderrBuf, fmt.Errorf("Unable to setup stdout for command: %s", err)
	}

	stderrIn, err := cmd.StderrPipe()
	if err != nil {
		return stdoutBuf, stderrBuf, fmt.Errorf("Unable to setup stderr for command: %s", err)
	}

	if err := cmd.Start(); err != nil {
		return stdoutBuf, stderrBuf, fmt.Errorf("failed to start the command: %s", err)
	}

	var wg sync.WaitGroup
	wg.Add(1)

	var errStdout, errStderr error
	go func() {
		_, errStdout = io.Copy(&stdoutBuf, stdoutIn)
		wg.Done()
	}()

	_, errStderr = io.Copy(&stderrBuf, stderrIn)
	wg.Wait()

	if err := cmd.Wait(); err != nil {
		return stdoutBuf, stderrBuf, fmt.Errorf("cmd.Run failed with %s", err)
	}

	if errStdout != nil {
		return stdoutBuf, stderrBuf, fmt.Errorf("failed to capture stdout: %s", errStdout)
	}

	if errStderr != nil {
		return stdoutBuf, stderrBuf, fmt.Errorf("failed to capture stderr: %s", errStderr)
	}

	return stdoutBuf, stderrBuf, nil
}

func WrapCommandForLogging(cmd string, outputfile string) string {
	return fmt.Sprintf("echo $'\n'$(date) '%s' %s >> %s && %s 1> >(tee -a %s) 2> >(tee -a %s >&2)", strings.ReplaceAll(cmd, "'", "\""), GetScrubPasswordCommand(), outputfile, cmd, outputfile, outputfile)
}

// do not log output if secrets are present
func WrapCommandForLoggingSecret(cmd string, outputfile string) string {
	return fmt.Sprintf("echo $'\n'$(date) '%s' %s >> %s && %s 2> >(tee -a %s >&2)", strings.ReplaceAll(cmd, "'", "\""), GetScrubPasswordCommand(), outputfile, cmd, outputfile)
}

func GetScrubPasswordCommand() string {
	return "| sed 's/-password [^ ]*/-password ***/g' | sed 's/BASE64:[^\\x27]*/BASE64:***/g'"
}
