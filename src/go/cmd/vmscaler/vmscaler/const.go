// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package vmscaler

// default configuration parameters
const (
	DEFAULT_SKU = "Standard_DS14_v2"
	// the default is based on the following study https://github.com/Azure/Avere/blob/main/docs/azure_vm_provision_best_practices.md
	DEFAULT_VMS_PER_VMSS = 25
	MINIMUM_VMS_PER_VMSS = 16
	MAXIMUM_VMS_PER_VMSS = 250

	DEFAULT_VMSS_SINGLEPLACEMENTGROUP = false
	DEFAULT_VMSS_OVERPROVISION        = false
	DEFAULT_QUEUE_PREFIX              = "vmscaler"
)

const (
	TOTAL_NODES_TAG_KEY           = "TOTAL_NODES"
	LAST_TIME_AT_CAPACITY_TAG_KEY = "LAST_TIME_AT_CAPACITY"
	SEALED_TAG_KEY                = "SEALED"
)

const (
	VMSS_PREFIX = "vmss"
)
