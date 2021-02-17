// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

func FileMatches(inclusionList []string, exclusionList []string, filename string) bool {
	// if the lists are empty, include everything
	if len(inclusionList) == 0 && len(exclusionList) == 0 {
		return true
	}

	// exclusion takes priority
	for _, excludeStr := range exclusionList {
		if matched, err := filepath.Match(excludeStr, filename); err == nil && matched == true {
			return false
		}
	}

	// inclusion
	for _, includeStr := range inclusionList {
		if matched, err := filepath.Match(includeStr, filename); err == nil && matched == true {
			return true
		}
	}
	return false
}

// EnsureWarmPath ensures that the path is mounted and exists
func EnsureWarmPath(jobMountAddress string, jobExportPath string, jobBasePath string) (string, error) {
	return ensureJobPath(jobMountAddress, jobExportPath, jobBasePath, "", false)
}

func ensureJobPath(jobMountAddress string, jobExportPath string, jobBasePath string, jobpath string, createAllDirectories bool) (string, error) {
	localMountPath := GetLocalMountPath(jobMountAddress, jobExportPath)
	if err := MountPath(jobMountAddress, jobExportPath, localMountPath); err != nil {
		return localMountPath, err
	}
	jobSubmitterPath := path.Join(localMountPath, jobBasePath, jobpath)

	if createAllDirectories {
		if err := os.MkdirAll(jobSubmitterPath, os.ModePerm); err != nil {
			return jobSubmitterPath, err
		}
	} else {
		// verify the directory exists
		if _, err := os.Stat(jobSubmitterPath); err != nil {
			return jobSubmitterPath, err
		}
	}

	return jobSubmitterPath, nil
}

func GetLocalMountPath(jobMountAddress string, jobExportPath string) string {
	return path.Join(DefaultCacheWarmerMountPath, jobMountAddress, jobExportPath)
}

func MountPath(address string, exportPath string, localPath string) error {
	// is already mounted?
	if AlreadyMounted(localPath) {
		return nil
	}

	// ensure local path exists
	if e := os.MkdirAll(localPath, os.ModePerm); e != nil {
		return e
	}

	mountCmd := fmt.Sprintf("/bin/mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' %s:%s %s", address, exportPath, localPath)

	for retries := 0; ; retries++ {
		_, stderrBytes, err := BashCommand(mountCmd)
		if err == nil {
			return nil
		}
		log.Warning.Printf("command '%s' failed with error: '%v', '%s'", mountCmd, err, stderrBytes.String())
		if retries > MountRetryCount {

			return fmt.Errorf("Failure to mount after %d retries trying to mount %s", MountRetryCount, localPath)
		}
		time.Sleep(MountRetrySleepSeconds * time.Second)
	}
}

func AlreadyMounted(mountPath string) bool {
	checkMountCmd := fmt.Sprintf("/bin/mountpoint -q %s", mountPath)
	if _, _, err := BashCommand(checkMountCmd); err != nil {
		return false
	}
	return true
}

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

func IsDirectory(path string) (bool, error) {
	fileInfo, err := os.Stat(path)
	if err != nil {
		return false, err
	}
	return fileInfo.IsDir(), err
}
