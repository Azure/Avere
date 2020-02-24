// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

const (
	AvereAdminUsername        = "admin"
	MinNodesCount             = 3
	MaxNodesCount             = 16
	VfxtLogDateFormat         = "2006-01-02.15.04.05"
	VServerRangeSeperator     = "-"
	AverecmdRetryCount        = 30 // wait 5 minutes (ex. remove core filer gets perm denied for a while)
	AverecmdRetrySleepSeconds = 10
	AverecmdLogFile           = "~/averecmd.log"
	VServerName               = "vserver"

	// Platform
	PlatformAzure = "azure"

	// cache policies
	CachePolicyClientsBypass        = "Clients Bypassing the Cluster"
	CachePolicyReadCaching          = "Read Caching"
	CachePolicyReadWriteCaching     = "Read and Write Caching"
	CachePolicyFullCaching          = "Full Caching"
	CachePolicyTransitioningClients = "Transitioning Clients Before or After a Migration"

	// filer class
	FilerClassNetappNonClustered = "NetappNonClustered"
	FilerClassNetappClustered    = "NetappClustered"
	FilerClassEMCIsilon          = "EmcIsilon"
	FilerClassOther              = "Other"

	// filer retry
	FilerRetryCount        = 120
	FilerRetrySleepSeconds = 10

	// cluster stable, wait 40 minutes for cluster to become healthy
	ClusterStableRetryCount        = 240
	ClusterStableRetrySleepSeconds = 10

	// node change, wait 40 minutes for node increase or decrease
	NodeChangeRetryCount        = 240
	NodeChangeRetrySleepSeconds = 10

	// status's returned from Activity
	StatusComplete      = "complete"
	StatusCompleted     = "completed"
	StatusNodeRemoved   = "node(s) removed"
	CompletedPercent    = "100"
	NodeUp              = "up"
	AlertSeverityGreen  = "green"  // this means the alert is complete
	AlertSeverityYellow = "yellow" // this will eventually resolve itself
)
