// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

func (c *CoreFilerGeneric) CreateCoreFiler() *CoreFiler {
	return &CoreFiler{
		Name:            c.Name,
		FqdnOrPrimaryIp: c.NetworkName,
		CachePolicy:     c.PolicyName,
	}
}

func (c *CoreFilerGeneric) CreateAzureStorageFiler() *AzureStorageFiler {
	return &AzureStorageFiler{
		AccountName: GetAzureStorageAccount(c.Bucket),
		Container:   GetAzureStorageContainer(c.Bucket),
	}
}
