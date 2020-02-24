// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"regexp"
	"strings"
)

// GetErrorMatches will check stdout and stderr for regex, and return a string of all the matching lines
func GetErrorMatches(stdoutBuf bytes.Buffer, stderrBuf bytes.Buffer, errorRegex *regexp.Regexp) string {
	return fmt.Sprintf("%s%s", getErrorMatches(stdoutBuf, errorRegex), getErrorMatches(stderrBuf, errorRegex))
}

func getErrorMatches(b bytes.Buffer, errorRegex *regexp.Regexp) string {
	var sb strings.Builder

	r := bytes.NewReader(b.Bytes())
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		if matches := errorRegex.FindStringSubmatch(scanner.Text()); matches != nil {
			if len(matches) > 1 {
				sb.WriteString(fmt.Sprintf("STDIN: %s\n", matches[1]))
			}
		}
	}

	return sb.String()
}
