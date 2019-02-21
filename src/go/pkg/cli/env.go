// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cli

import (
	"fmt"
	"os"
)

// VerifyEnvVar confirms that the environment variable is defined, otherwise it prints an error message
func VerifyEnvVar(envvar string) bool {
	if _, available := os.LookupEnv(envvar); !available {
		fmt.Fprintf(os.Stderr, "ERROR: Missing Environment Variable %s\n", envvar)
		return false
	}
	return true
}

// GetEnv retrieves the environment variable triming leading or trailing quotes
func GetEnv(envVarName string) string {
	s := os.Getenv(envVarName)

	if len(s) > 0 && (s[0] == '"' || s[0] == '\'') {
		s = s[1:]
	}

	if len(s) > 0 && (s[len(s)-1] == '"' || s[len(s)-1] == '\'') {
		s = s[:len(s)-1]
	}

	return s
}
