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
	// a warm job specifies a full path warm job
	DefaultCacheJobSubmitterDir = ".cachewarmjob"
	// a warm worker job describes the files to warm in a path
	DefaultCacheWorkerJobsDir = ".cachewarmworkerjobs"

	// the base mount path
	DefaultCacheWarmerMountPath = "/mnt/cachewarmer"
	DefaultJobPath              = "job"
	DefaultWarmMountPath        = "warm"

	jobCheckInterval    = time.Duration(5) * time.Second  // check for jobs every 5 seconds
	refreshWorkInterval = time.Duration(30) * time.Second // update job timestamp every 30s
	staleFileAge        = time.Duration(60) * time.Second // take a work file if not updated for 60s

	// retry mounting for 10 minutes
	MountRetryCount        = 60
	MountRetrySleepSeconds = 10

	// this size is the most common, and will stand up the fastest
	VMSSNodeSize            = "Standard_D2s_v3"
	NodesPerNFSMountAddress = 6

	tick                      = time.Duration(10) * time.Millisecond // 10ms
	timeBetweenJobCheck       = time.Duration(5) * time.Second       // 5 second between checking for jobs
	timeBetweenWorkerJobCheck = time.Duration(5) * time.Second       // 5 second between checking for jobs

	// file read settings
	ReadPageSize           = MB
	timeBetweenCancelCheck = time.Duration(100) * time.Millisecond // 100ms

	WorkerMultiplier          = 2
	WorkerReadWorkItemsAtOnce = 50
	WorkerReadFilesAtOnce     = 1000

	// size of slice for the locked paths
	LockedWorkItemStartSliceSize = 1024
)
