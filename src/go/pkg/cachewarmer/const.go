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
	PrimeIndexIncr       = 59

	WarmPathJobQueueSuffix = "job"
	WorkQueueSuffix        = "work"

	// the base mount path
	DefaultCacheWarmerMountPath = "/mnt/cachewarmer"
	DefaultJobPath              = "job"
	DefaultWarmMountPath        = "warm"

	jobCheckInterval    = time.Duration(5) * time.Second  // check for jobs every 5 seconds
	refreshWorkInterval = time.Duration(10) * time.Second // update job timestamp every 30s
	staleFileAge        = time.Duration(60) * time.Second // take a work file if not updated for 60s

	NumberOfMessagesToDequeue    = 1
	CacheWarmerVisibilityTimeout = time.Duration(60) * time.Second // 10 minute visibility timeout

	// retry mounting for 10 minutes
	MountRetryCount        = 60
	MountRetrySleepSeconds = 10

	MinimumAvereNodesPerCluster = 3

	// this size is the most common, and will stand up the fastest
	VMSSNodeSize            = "Standard_D2s_v3"
	VmssName                = "cwvmss"
	NodesPerNFSMountAddress = 6
	MarketPlacePublisher    = "Canonical"
	MarketPlaceOffer        = "UbuntuServer"
	MarketPlaceSku          = "18.04-LTS"

	tick                        = time.Duration(1) * time.Millisecond // 1ms
	timeBetweenJobCheck         = time.Duration(5) * time.Second      // 5 second between checking for jobs
	timeBetweenWorkerJobCheck   = time.Duration(5) * time.Second      // 5 second between checking for jobs
	timeBetweenEOF              = time.Duration(5) * time.Second      // 5 second between EOF
	timeToDeleteVMSSAfterNoJobs = time.Duration(20) * time.Second     // 20 seconds before deleting the VMSS
	failureTimeToDeleteVMSS     = time.Duration(15) * time.Minute     // after 15 minutes of failure, ensure vmss deleted

	// file read settings
	ReadPageSize           = 10 * MB
	timeBetweenCancelCheck = time.Duration(100) * time.Millisecond // 100ms

	WorkerMultiplier        = 2
	MinimumJobsBeforeRefill = 100

	// size of slice for the locked paths
	LockedWorkItemStartSliceSize = 1024
)
