// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"log"
	"os"

	"github.com/hashicorp/terraform-plugin-sdk/v2/plugin"
)

func usage(programName string) {
	fmt.Printf("Usage: %s VFXT_RESTORE_DIRECTORY\n", programName)
	fmt.Printf("\n")
	fmt.Printf("This vfxt terraform provider will also translate a vfxt backup directory\n")
	fmt.Printf("to terraform files.  This is useful for backup scenarios\n")
}

func main() {
	// check for single parameter
	if len(os.Args) == 2 {
		if os.Args[1] == "-?" || os.Args[1] == "-h" || os.Args[1] == "--help" {
			usage(os.Args[0])
			os.Exit(0)
		}
		vfxtBackupDirectory := os.Args[1]
		if _, err := os.Stat(vfxtBackupDirectory); err == nil {
			if IsVfxtBackupDir(vfxtBackupDirectory) {
				err := WriteTerraformFiles(vfxtBackupDirectory)
				if err != nil {
					fmt.Printf("%v\n", vfxtBackupDirectory)
				}
				os.Exit(0)
			}
		}
	}

	log.SetFlags(log.Flags() &^ (log.Ldate | log.Ltime))

	plugin.Serve(&plugin.ServeOpts{
		ProviderFunc: Provider,
	})
}
