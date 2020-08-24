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

func InitializeCustomSetting(customSettingString string) *CustomSetting {
	return &CustomSetting{
		Name:      GetCustomSettingName(customSettingString),
		CheckCode: getCustomSettingCheckCode(customSettingString),
		Value:     getCustomSettingValue(customSettingString),
	}
}

func (c *CustomSetting) GetCustomSettingCommand() string {
	return fmt.Sprintf("%s %s %s", c.Name, c.CheckCode, c.Value)
}

func GetCustomSettingName(customSettingString string) string {
	return strings.Split(customSettingString, " ")[0]
}

func GetVServerCustomSettingName(customSetting string) string {
	return fmt.Sprintf("%s1.%s", VServerName, customSetting)
}

func GetFilerCustomSettingName(internalName string, customSetting string) string {
	return fmt.Sprintf("%s.%s", internalName, customSetting)
}

func IsAutoWanOptimizeCustomSetting(customSettingString string) bool {
	return GetCustomSettingName(customSettingString) == GetCustomSettingName(AutoWanOptimizeCustomSetting)
}

func IsQuotaBalanceCustomSetting(customSettingString string) bool {
	customSettingName := GetCustomSettingName(customSettingString)
	return customSettingName == GetCustomSettingName(QuotaCacheMoveMax) ||
		customSettingName == GetCustomSettingName(QuotaDivisorFloor) ||
		customSettingName == GetCustomSettingName(QuotaMaxMultiplierForInvalidatedMassQuota)
}

func getCustomSettingCheckCode(customSettingString string) string {
	parts := strings.Split(customSettingString, " ")
	if len(parts) > 1 {
		return parts[1]
	}
	return ""
}

func getCustomSettingValue(customSettingString string) string {
	parts := strings.Split(customSettingString, " ")
	if len(parts) > 2 {
		var sb strings.Builder
		for i := 2; i < len(parts); i++ {
			sb.WriteString(fmt.Sprintf("%s ", parts[i]))
		}
		return strings.TrimSpace(sb.String())
	}
	return ""
}
