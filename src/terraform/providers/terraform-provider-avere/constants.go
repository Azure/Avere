// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

const (
	AvereAdminUsername            = "admin"
	MinNodesCount                 = 3
	MaxNodesCount                 = 16
	MinVserverIpCount             = MinNodesCount
	MaxVserverIpCount             = 2 * MaxNodesCount
	MinFixedQuotaPercent          = 0
	MaxFixedQuotaPercent          = 100
	DefaultSshPort                = 22
	VfxtLogDateFormat             = "2006-01-02.15.04.05"
	VServerRangeSeperator         = "-"
	AverecmdRetryCount            = 60 // wait 10 minutes (ex. remove core filer gets perm denied for a while)
	AverecmdRetrySleepSeconds     = 10
	ShellcmdRetryCount            = 60 // wait 10 minutes (ex. apt install waiting for lock to release)
	ShellcmdRetrySleepSeconds     = 10
	ClusterAliveRetryCount        = 3 // try 3 times to see if the cluster is alive
	ClusterAliveRetrySleepSeconds = 5
	AverecmdLogFile               = "~/averecmd.log"
	VServerName                   = "vserver"
	VfxtKeyPubFile                = "~/vfxt_ssh_key_data.pub"
	ShellLogFile                  = "~/shell.log"

	// Platform
	PlatformAzure = "azure"

	// cluster sizes
	ClusterSkuUnsupportedTest = "unsupported_test_SKU"
	ClusterSkuProd            = "prod_sku"

	// cache policies
	CachePolicyClientsBypass                 = "Clients Bypassing the Cluster"
	CachePolicyReadCaching                   = "Read Caching"
	CachePolicyReadWriteCaching              = "Read and Write Caching"
	CachePolicyFullCaching                   = "Full Caching"
	CachePolicyTransitioningClients          = "Transitioning Clients Before or After a Migration"
	CachePolicyIsolatedCloudWorkstation      = "Isolated Cloud Workstation"
	CachePolicyCollaboratingCloudWorkstation = "Collaborating Cloud Workstation"
	CachePolicyReadOnlyHighVerificationTime  = "Read Only High Verification Time"

	CachePolicyIsolatedCloudWorkstationCheckAttributes      = "{}"
	CachePolicyCollaboratingCloudWorkstationCheckAttributes = "{'checkAttrPeriod':30,'checkDirAttrPeriod':30}"
	CachePolicyReadOnlyHighVerificationTimeCheckAttributes  = "{'checkAttrPeriod':10800,'checkDirAttrPeriod':10800}"

	QuotaCacheMoveMax = "cfs.quotaCacheMoveMax DN 50" // 50 is the max
	QuotaDivisorFloor = "cfs.quotaCacheDivisorFloor CQ %d"
	// This setting is used to speed up the number of blocks
	// to be assigned to a policy. Decreasing it could reduce
	// the impact from the early added corefiler default is 20
	QuotaMaxMultiplierForInvalidatedMassQuota = "cfs.maxMultiplierForInvalidatedMassQuota VS 2"
	QuotaWaitMinutes                          = 20 // wait up to 20 minutes for the quota to balance
	TargetPercentageError                     = float32(0.01)
	QuotaSpeedUpDeleteFirstFiler              = true

	TerraformAutoMessage           = "Customer Added Custom Setting via Terraform"
	TerraformOverriddenAutoMessage = "Customer Overridden Deprecated Custom Setting via Terraform"
	TerraformFeatureMessage        = "Terraform Feature"
	// features that are custom settings
	AutoWanOptimizeCustomSetting = "autoWanOptimize YF 2"
	CustomSettingOverride        = "override "
	NFSConnMultCustomSetting     = "nfsConnMult YW %d"
	MinNFSConnMult               = 1
	MaxNFSConnMult               = 23
	DefaultNFSConnMult           = 4

	AnalyticsClusterFilersRaw = "cluster_filers_raw"

	CacheModeReadWrite = "read-write"
	CacheModeReadOnly  = "read"

	WriteBackDelayDefault = 30

	// user policies for admin.addUser Avere xml rpc call
	UserReadOnly  = "ro"
	UserReadWrite = "rw"
	AdminUserName = "admin"

	// filer class
	FilerClassNetappNonClustered = "NetappNonClustered"
	FilerClassNetappClustered    = "NetappClustered"
	FilerClassEMCIsilon          = "EmcIsilon"
	FilerClassOther              = "Other"
	FilerClassAvereCloud         = "AvereCloud"

	// VServer retry
	VServerRetryCount        = 60
	VServerRetrySleepSeconds = 10

	// filer retry
	FilerRetryCount        = 120
	FilerRetrySleepSeconds = 10

	// cluster stable, wait 40 minutes for cluster to become healthy
	ClusterStableRetryCount        = 240
	ClusterStableRetrySleepSeconds = 10

	// node change, wait 40 minutes for node increase or decrease
	NodeChangeRetryCount        = 240
	NodeChangeRetrySleepSeconds = 10

	// only wait 10 minutes for support uploads
	UploadGSIRetryCount        = 60
	UploadGSIRetrySleepSeconds = 10

	// status's returned from Activity
	StatusComplete      = "complete"
	StatusCompleted     = "completed"
	StatusNodeRemoved   = "node(s) removed"
	CompletedPercent    = "100"
	NodeUp              = "up"
	AlertSeverityGreen  = "green"  // this means the alert is complete
	AlertSeverityYellow = "yellow" // this will eventually resolve itself

	// the cloud filer export
	CloudFilerExport = "/"

	// the share permssions
	PermissionsPreserve = "preserve" // this is the default for NFS shares
	PermissionsModebits = "modebits" // this is the default for the Azure Storage Share

	PrimaryClusterIPKey = "IP"

	DefaultExportPolicyName = "default"

	DefaultDirectoryServiceName = "default"

	FaultString = "faultString"
	FaultCode   = "faultCode"
	MultiCall   = "--json system.multicall"

	CIFSUsernameSourceAD    = "AD"
	CIFSUsernameSourceFile  = "File"
	CIFSSelfPasswdUriStrFmt = "https://%s/avere/avere-user.txt"
	CIFSSelfGroupUriStrFmt  = "https://%s/avere/avere-group.txt"

	ProactiveSupportDisabled = "Disabled"
	ProactiveSupportSupport  = "Support"
	ProactiveSupportAPI      = "API"
	ProactiveSupportFull     = "Full"
)

// terraform schema constants - avoids bugs on schema name changes
const (
	controller_address                    = "controller_address"
	controller_admin_username             = "controller_admin_username"
	controller_admin_password             = "controller_admin_password"
	controller_ssh_port                   = "controller_ssh_port"
	run_local                             = "run_local"
	allow_non_ascii                       = "allow_non_ascii"
	location                              = "location"
	platform                              = "platform"
	azure_resource_group                  = "azure_resource_group"
	azure_network_resource_group          = "azure_network_resource_group"
	azure_network_name                    = "azure_network_name"
	azure_subnet_name                     = "azure_subnet_name"
	ntp_servers                           = "ntp_servers"
	timezone                              = "timezone"
	dns_server                            = "dns_server"
	dns_domain                            = "dns_domain"
	dns_search                            = "dns_search"
	proxy_uri                             = "proxy_uri"
	cluster_proxy_uri                     = "cluster_proxy_uri"
	image_id                              = "image_id"
	vfxt_cluster_name                     = "vfxt_cluster_name"
	vfxt_admin_password                   = "vfxt_admin_password"
	vfxt_ssh_key_data                     = "vfxt_ssh_key_data"
	vfxt_node_count                       = "vfxt_node_count"
	node_size                             = "node_size"
	node_cache_size                       = "node_cache_size"
	vserver_first_ip                      = "vserver_first_ip"
	vserver_ip_count                      = "vserver_ip_count"
	global_custom_settings                = "global_custom_settings"
	vserver_settings                      = "vserver_settings"
	enable_support_uploads                = "enable_support_uploads"
	enable_rolling_trace_data             = "enable_rolling_trace_data"
	active_support_upload                 = "active_support_upload"
	enable_secure_proactive_support       = "enable_secure_proactive_support"
	cifs_ad_domain                        = "cifs_ad_domain"
	cifs_server_name                      = "cifs_server_name"
	cifs_username                         = "cifs_username"
	cifs_password                         = "cifs_password"
	cifs_flatfile_passwd_uri              = "cifs_flatfile_passwd_uri"
	cifs_flatfile_group_uri               = "cifs_flatfile_group_uri"
	cifs_flatfile_passwd_b64z             = "cifs_flatfile_passwd_b64z"
	cifs_flatfile_group_b64z              = "cifs_flatfile_group_b64z"
	cifs_organizational_unit              = "cifs_organizational_unit"
	cifs_trusted_active_directory_domains = "cifs_trusted_active_directory_domains"
	enable_extended_groups                = "enable_extended_groups"
	user_assigned_managed_identity        = "user_assigned_managed_identity"
	user                                  = "user"
	name                                  = "name"
	password                              = "password"
	permission                            = "permission"
	core_filer                            = "core_filer"
	core_filer_name                       = "name"
	fqdn_or_primary_ip                    = "fqdn_or_primary_ip"
	cache_policy                          = "cache_policy"
	auto_wan_optimize                     = "auto_wan_optimize"
	nfs_connection_multiplier             = "nfs_connection_multiplier"
	ordinal                               = "ordinal"
	fixed_quota_percent                   = "fixed_quota_percent"
	custom_settings                       = "custom_settings"
	junction                              = "junction"
	namespace_path                        = "namespace_path"
	cifs_share_name                       = "cifs_share_name"
	cifs_share_ace                        = "cifs_share_ace"
	cifs_create_mask                      = "cifs_create_mask"
	cifs_dir_mask                         = "cifs_dir_mask"
	core_filer_export                     = "core_filer_export"
	export_subdirectory                   = "export_subdirectory"
	export_rule                           = "export_rule"
	azure_storage_filer                   = "azure_storage_filer"
	account_name                          = "account_name"
	container_name                        = "container_name"
	vfxt_management_ip                    = "vfxt_management_ip"
	vserver_ip_addresses                  = "vserver_ip_addresses"
	node_names                            = "node_names"
	junction_namespace_path               = "junction_namespace_path"
	primary_cluster_ips                   = "primary_cluster_ips"
	licensing_id                          = "licensing_id"
	mass_filer_mappings                   = "mass_filer_mappings"
)
