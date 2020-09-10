// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

func (j *Junction) IsEqual(j2 *Junction) bool {
	// don't compare share permissions since share permissions is
	// returned when listing junctions
	return j.NameSpacePath == j2.NameSpacePath &&
		j.CoreFilerName == j2.CoreFilerName &&
		j.CoreFilerExport == j2.CoreFilerExport &&
		j.ExportSubdirectory == j2.ExportSubdirectory
}
