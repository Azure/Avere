// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"strings"
)

func (j *Junction) IsEqual(j2 *Junction) bool {
	// don't compare share permissions since share permissions is
	// returned when listing junctions
	return j.NameSpacePath == j2.NameSpacePath &&
		j.CoreFilerName == j2.CoreFilerName &&
		j.CoreFilerExport == j2.CoreFilerExport &&
		j.ExportSubdirectory == j2.ExportSubdirectory &&
		j.PolicyName == j2.PolicyName &&
		ExportRulesEqual(j.ExportRules, j2.ExportRules) &&
		j.CifsShareName == j2.CifsShareName &&
		ShareAcesEqual(j.CifsAces, j2.CifsAces)
}

func NewJunction(
	nameSpacePath string,
	coreFilerName string,
	coreFilerExport string,
	exportSubdirectory string,
	sharePermissions string,
	exportRulesRaw string,
	cifsShareName string,
	cifsAcesRaw string) (*Junction, error) {
	exportRules, err := ParseExportRules(exportRulesRaw)
	if err != nil {
		return nil, fmt.Errorf("Error: exportRules parsing failed: %s", err)
	}
	cifsAces, err := ParseShareAces(cifsAcesRaw)
	if err != nil {
		return nil, fmt.Errorf("Error: cifsAces parsing failed: %s", err)
	}
	policyName := DefaultExportPolicyName
	if len(exportRules) > 0 {
		policyName = GenerateExportPolicyName(nameSpacePath)
	}
	return &Junction{
		NameSpacePath:      nameSpacePath,
		CoreFilerName:      coreFilerName,
		CoreFilerExport:    coreFilerExport,
		ExportSubdirectory: exportSubdirectory,
		PolicyName:         policyName,
		SharePermissions:   sharePermissions,
		ExportRules:        exportRules,
		CifsShareName:      cifsShareName,
		CifsAces:           cifsAces,
	}, nil
}

func GenerateExportPolicyName(junctionNameSpacePath string) string {
	// the policy name may only have letters, numbers, underscores, and hyphens
	return fmt.Sprintf("tfauto_%s_%s", VServerName, strings.ReplaceAll(junctionNameSpacePath, "/", "-"))
}
