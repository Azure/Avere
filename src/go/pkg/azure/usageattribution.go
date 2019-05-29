// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
// Package azure implements various azure tools
package azure

import (
	"context"
	"fmt"
)

type usagekey string

const usageAttributionKey usagekey = "usageattribution"

// set usage attribution on the context - https://docs.microsoft.com/en-us/azure/marketplace/azure-partner-customer-usage-attribution
func SetUsageAttribution(ctx context.Context, usageGuid string) context.Context {
	return context.WithValue(ctx, usageAttributionKey, fmt.Sprintf("pid-%s", usageGuid))
}

// get usage attribution from the context - https://docs.microsoft.com/en-us/azure/marketplace/azure-partner-customer-usage-attribution
func GetUsageAttribution(ctx context.Context) (string, bool) {
	if v := ctx.Value(usageAttributionKey); v != nil {
		return v.(string), true
	}
	return "", false
}
