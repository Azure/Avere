// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"strings"
)

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

func IsAutoWanOptimizeCustomSetting(customSetting string) bool {
	return GetCustomSettingName(customSetting) == GetCustomSettingName(AutoWanOptimizeCustomSetting)
}

func IsQuotaBalanceCustomSetting(customSetting string) bool {
	customSettingName := GetCustomSettingName(customSetting)
	return customSettingName == GetCustomSettingName(QuotaCacheMoveMax) ||
		customSettingName == GetCustomSettingName(QuotaDivisorFloor) ||
		customSettingName == GetCustomSettingName(QuotaMaxMultiplierForInvalidatedMassQuota)
}

func IsCustomSettingDeprecated(customSetting string) bool {
	deprecatedCustomSettings := []string{
		"cluster.ctcConnMult",
		"cfs.quotaCacheMoveMax",
		"cfs.quotaCacheDivisorFloor",
		"cluster.HaBackEndTimeout",
		"cluster.NfsBackEndTimeout",
		"cluster.NfsFrontEndCwnd",
		"NfsFrontEndSobuf",
		"rwsize",
		"vcm.alwaysForwardReadSize",
		"vcm.disableReadAhead",
		"always_forward",
	}

	c := InitializeCustomSetting(customSetting)
	// this setting has been overridden
	if c.Override {
		return false
	}

	for _, deprecatedSetting := range deprecatedCustomSettings {
		if c.Name == deprecatedSetting {
			return true
		}
	}

	return false
}

func isOverrideEnabled(customSetting string) (bool, string) {
	result := strings.TrimPrefix(customSetting, CustomSettingOverride)
	return result != customSetting, result
}
