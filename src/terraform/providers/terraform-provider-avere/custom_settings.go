// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"strings"
)

const (
	AutoWanOptimizeDeprecatedError = "Please remove '%s', the autoWanOptimize custom setting has been deprecated.  Instead use the auto_wan_optimize flag, see provider docs for more information: https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#auto_wan_optimize.  Also, autoWanOptimize it not required for storage filers as it is always automatically applied for cloud storage filers."

	QuotaBalanceError = "Please remove '%s'.  This custom setting is deprecated and is now used as part of quota balancing: https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#fixed_quota_percent."

	NFSConnectionMultiplierError = "Please remove '%s'.  Instead use the nfs_connection_multiplier flag, see provider docs for more information: https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#nfs_connection_multiplier."

	GenericDeprecatedError = "The custom setting '%s' has been deprecated and is no longer needed.  If support has recommended the setting, to override the deprecation, prefix the custom setting with 'override'"
)

var deprecatedCustomSettings = map[string]string{
	// FEATURES - these are the features
	"cfs.quotaCacheMoveMax":                    QuotaBalanceError,              // use the fixed_quota_percent instead
	"cfs.quotaCacheDivisorFloor":               QuotaBalanceError,              // use the fixed_quota_percent instead
	"cfs.maxMultiplierForInvalidatedMassQuota": QuotaBalanceError,              // use the fixed_quota_percent instead
	"autoWanOptimize":                          AutoWanOptimizeDeprecatedError, // use the auto_wan_optimize feature instead
	"nfsConnMult":                              NFSConnectionMultiplierError,   // use the nfs_connection_multiplier feature instead

	// OVERRIDABLE DEPRECATED
	"cluster.ctcConnMult":        GenericDeprecatedError, // defaults to 8
	"cluster.HaBackEndTimeout":   GenericDeprecatedError,
	"cluster.NfsBackEndTimeout":  GenericDeprecatedError,
	"cluster.NfsFrontEndCwnd":    GenericDeprecatedError,
	"NfsFrontEndSobuf":           GenericDeprecatedError,
	"rwsize":                     GenericDeprecatedError,
	"vcm.alwaysForwardReadSize":  GenericDeprecatedError,
	"vcm.disableReadAhead":       GenericDeprecatedError,
	"always_forward":             GenericDeprecatedError, // defaults to 1
	"client_wt_preferred":        GenericDeprecatedError,
	"client_rt_preferred":        GenericDeprecatedError,
	"cluster.CtcBackEndTimeout":  GenericDeprecatedError,
	"cluster.HAVoteTimeToLive":   GenericDeprecatedError,
	"vcm.vcm_waWriteBlocksValid": GenericDeprecatedError,
	"doStrictNlmOhMatching":      GenericDeprecatedError,
	"svidshift":                  GenericDeprecatedError,
	"skipNfsExportTask":          GenericDeprecatedError,
	"cfs.fileCountLimit":         GenericDeprecatedError,
}

func ValidateCustomSettingFormat(customSettingString string) error {
	customSetting := InitializeCustomSetting(customSettingString)
	if len(customSetting.Name) == 0 || len(customSetting.CheckCode) == 0 || len(customSetting.Value) == 0 {
		return fmt.Errorf("CustomSetting '%s' is invalid.  It should be of the format 'CUSTOMSETTINGNAME CHECKCODE VALUE'", customSettingString)
	}
	return nil
}

func InitializeCustomSetting(customSetting string) *CustomSetting {
	override, nonOverriddenCustomSetting := isOverrideEnabled(customSetting)

	parts := strings.Split(nonOverriddenCustomSetting, " ")

	name := parts[0]

	checkCode := ""
	if len(parts) > 1 {
		checkCode = parts[1]
	}

	value := ""
	if len(parts) > 2 {
		var sb strings.Builder
		for i := 2; i < len(parts); i++ {
			sb.WriteString(fmt.Sprintf("%s ", parts[i]))
		}
		value = strings.TrimSpace(sb.String())
	}

	return &CustomSetting{
		Name:      name,
		CheckCode: checkCode,
		Value:     value,
		Override:  override,
	}
}

func (c *CustomSetting) GetCustomSettingCommand() string {
	return fmt.Sprintf("%s %s %s", c.Name, c.CheckCode, c.Value)
}

func GetCustomSettingName(customSetting string) string {
	c := InitializeCustomSetting(customSetting)
	return c.Name
}

func GetVServerCustomSetting(customSetting string) string {
	c := InitializeCustomSetting(customSetting)
	return fmt.Sprintf("%s1.%s", VServerName, c.GetCustomSettingCommand())
}

func GetFilerCustomSetting(internalName string, customSetting string) string {
	c := InitializeCustomSetting(customSetting)
	return fmt.Sprintf("%s.%s", internalName, c.GetCustomSettingCommand())
}

func (c *CustomSetting) SetFilerCustomSettingName(internalName string) {
	c.Name = fmt.Sprintf("%s.%s", internalName, c.Name)
}

func IsAutoWanOptimizeCustomSetting(customSettingName string) bool {
	return customSettingName == GetCustomSettingName(AutoWanOptimizeCustomSetting)
}

func IsQuotaBalanceCustomSetting(customSettingName string) bool {
	return customSettingName == GetCustomSettingName(QuotaCacheMoveMax) ||
		customSettingName == GetCustomSettingName(QuotaDivisorFloor) ||
		customSettingName == GetCustomSettingName(QuotaMaxMultiplierForInvalidatedMassQuota)
}

func IsNFSConnMultCustomSetting(customSettingName string) bool {
	return customSettingName == GetCustomSettingName(NFSConnMultCustomSetting)
}

func IsFeature(name string) bool {
	return IsAutoWanOptimizeCustomSetting(name) ||
		IsQuotaBalanceCustomSetting(name) ||
		IsNFSConnMultCustomSetting(name)
}

func IsCustomSettingDeprecated(customSetting string) (bool, error) {
	c := InitializeCustomSetting(customSetting)
	if customSettingErr, ok := deprecatedCustomSettings[c.Name]; ok {
		if c.Override && !IsFeature(c.Name) {
			return false, nil
		}
		return true, fmt.Errorf(customSettingErr, customSetting)
	}
	return false, nil
}

func GetNFSConnectionMultiplierSetting(nfsConnectionMultiplierSetting int) string {
	return fmt.Sprintf(NFSConnMultCustomSetting, nfsConnectionMultiplierSetting)
}

func (c *CustomSetting) GetTerraformMessage() string {
	return getTerraformCustomMessage(c.Override)
}

func GetTerraformMessage(customSetting string) string {
	overridden, _ := isOverrideEnabled(customSetting)
	return getTerraformCustomMessage(overridden)
}

func getTerraformCustomMessage(overridden bool) string {
	if overridden {
		return TerraformOverriddenAutoMessage
	}
	return TerraformAutoMessage
}

func isOverrideEnabled(customSetting string) (bool, string) {
	result := strings.TrimPrefix(customSetting, CustomSettingOverride)
	return result != customSetting, result
}
