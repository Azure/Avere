// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package cachewarmer

import (
	"time"
)

// sizes
const (
	B = 1 << (10 * iota)
	KB
	MB
	GB
)

const (
	MinimumSingleFileSize = int64(100 * MB)
	MaximumJobSize        = int64(1500 * MB)
	allFilesOrBytes       = int64(-1)
	MaximumFilesToRead    = 200

	// golang uses an 8192 buffer passed to getdents64 so we'll choose 128 because we get these on the first call anyway
	MinimumJobsOnDirRead = 128

	WarmPathJobQueueSuffix = "job"
	WorkQueueSuffix        = "work"

	// the base mount path
	DefaultCacheWarmerMountPath = "/mnt/cachewarmer"

	NumberOfMessagesToDequeue    = 1
	CacheWarmerVisibilityTimeout = time.Duration(60) * time.Second // 1 minute visibility timeout

	// retry mounting for 10 minutes
	MountRetryCount        = 60
	MountRetrySleepSeconds = 10

	// this size is the most common, and will stand up the fastest
	VMSSNodeSize = "Standard_D2s_v3"
	VmssName     = "cwvmss"

	/* by default Ubuntu doesn't install NFS and we need a distro with NFS installed by default for airgapped environments
	MarketPlacePublisher    = "Canonical"
	MarketPlaceOffer        = "UbuntuServer"
	MarketPlaceSku          = "18.04-LTS"
	PlanName             = ""
	PlanPublisherName    = ""
	PlanProductName      = ""
	*/

	// the controller will work in an airgapped environment
	MarketPlacePublisher = "microsoft-avere"
	MarketPlaceOffer     = "vfxt"
	MarketPlaceSku       = "avere-vfxt-controller"
	PlanName             = "avere-vfxt-controller"
	PlanPublisherName    = "microsoft-avere"
	PlanProductName      = "vfxt"

	tick                        = time.Duration(1) * time.Millisecond   // 1ms
	timeBetweenJobCheck         = time.Duration(2) * time.Second        // 2 seconds between checking for jobs
	refreshWorkInterval         = time.Duration(10) * time.Second       // update job timestamp every 30s
	timeBetweenWorkerJobCheck   = time.Duration(100) * time.Millisecond // 100ms between checking for jobs
	timeToDeleteVMSSAfterNoJobs = time.Duration(20) * time.Second       // 20 seconds before deleting the VMSS
	failureTimeToDeleteVMSS     = time.Duration(15) * time.Minute       // after 15 minutes of failure, ensure vmss deleted

	// file read settings
	ReadPageSize           = 10 * MB
	timeBetweenCancelCheck = time.Duration(100) * time.Millisecond // 100ms

	WorkerMultiplier        = 2
	MinimumJobsBeforeRefill = 100

	SubscriptionIdEnvVar = "AZURE_SUBSCRIPTION_ID"
)
