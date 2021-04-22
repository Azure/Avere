// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"regexp"

	"golang.org/x/crypto/ssh"
)

type IaasPlatform interface {
	CreateVfxt(avereVfxt *AvereVfxt) error
	AddIaasNodeToCluster(avereVfxt *AvereVfxt) error
	DestroyVfxt(avereVfxt *AvereVfxt) error
	DeleteVfxtIaasNode(avereVfxt *AvereVfxt, nodeName string) error
	GetSupportName(avereVfxt *AvereVfxt, uniqueName string) (string, error)
}

type AvereVfxt struct {
	ControllerAddress string
	ControllerUsename string

	SshAuthMethod ssh.AuthMethod
	SshPort       int

	RunLocal             bool
	UseAvailabilityZones bool
	AllowNonAscii        bool

	Platform IaasPlatform

	AvereVfxtName          string
	AvereVfxtSupportName   string
	AvereAdminPassword     string
	AvereSshKeyData        string
	EnableSupportUploads   bool
	EnableRollingTraceData bool
	RollingTraceFlag       string
	ActiveSupportUpload    bool
	SecureProactiveSupport string
	NodeCount              int
	NodeSize               string
	NodeCacheSize          int
	EnableNlm              bool
	FirstIPAddress         string
	LastIPAddress          string

	CifsAdDomain                      string
	CifsNetbiosDomainName             string
	CifsDCAddresses                   string
	CifsServerName                    string
	CifsUsername                      string
	CifsPassword                      string
	CifsFlatFilePasswdURI             string
	CifsFlatFileGroupURI              string
	CifsFlatFilePasswdB64z            string
	CifsFlatFileGroupB64z             string
	CifsRidMappingBaseInteger         int
	CifsOrganizationalUnit            string
	CifsTrustedActiveDirectoryDomains string
	EnableExtendedGroups              bool

	LoginServicesLDAPServer       string
	LoginServicesLDAPBasedn       string
	LoginServicesLDAPBinddn       string
	LoginServicesLDAPBindPassword string

	UserAssignedManagedIdentity string

	NtpServers string
	Timezone   string
	DnsServer  string
	DnsDomain  string
	DnsSearch  string

	ProxyUri        string
	ClusterProxyUri string

	ImageId string

	ManagementIP       string
	VServerIPAddresses *[]string
	NodeNames          *[]string

	rePasswordReplace  *regexp.Regexp
	rePasswordReplace2 *regexp.Regexp
}

///////////////////////////////////////////////////////////
// The following types are used to parse json from
// averecmd.
///////////////////////////////////////////////////////////

type NFSExport struct {
	Path string `json:"path"`
}

type Node struct {
	Name             string            `json:"name"`
	State            string            `json:"state"`
	PrimaryClusterIP map[string]string `json:"primaryClusterIP"`
}

type VServerClientIPHome struct {
	NodeName  string `json:"current"`
	IPAddress string `json:"ip"`
}

type Activity struct {
	Id      string `json:"id"`
	Status  string `json:"status"`
	State   string `json:"state"`
	Percent string `json:"percent"`
}

type Alert struct {
	Name     string `json:"name"`
	Severity string `json:"severity"`
	Message  string `json:"message"`
}

type User struct {
	Name       string `json:"name"`
	Permission string `json:"permission"`
	Password   string
}

type CoreFilerGeneric struct {
	Name         string `json:"name"`
	NetworkName  string `json:"networkName"`
	PolicyName   string `json:"policyName"`
	InternalName string `json:"internalName"`
	FilerClass   string `json:"filerClass"`
	Bucket       string `json:"bucket"`
}

type CoreFiler struct {
	Name                    string `json:"name"`
	FqdnOrPrimaryIp         string `json:"networkName"`
	FilerClass              string `json:"filerClass"`
	CachePolicy             string `json:"policyName"`
	Ordinal                 int
	FixedQuotaPercent       int
	AutoWanOptimize         bool
	NfsConnectionMultiplier int
	CustomSettings          []*CustomSetting
}

// an Azure Storage Account Filer can be used from a vFXT running in
// any platform
type AzureStorageFiler struct {
	AccountName    string
	Container      string
	Ordinal        int
	CustomSettings []*CustomSetting
}

type Junction struct {
	NameSpacePath          string `json:"path"`
	CoreFilerName          string `json:"mass"`
	CoreFilerExport        string `json:"export"`
	ExportSubdirectory     string `json:"subdir"`
	PolicyName             string `json:"policy"`
	SharePermissions       string
	ExportRules            map[string]*ExportRule
	CifsShareName          string
	CoreFilerCifsShareName string `json:"sharename"`
	CifsAces               map[string]*ShareAce
	CifsCreateMask         string
	CifsDirMask            string
}

type CustomSetting struct {
	Name      string `json:"name"`
	Value     string `json:"value"`
	CheckCode string `json:"checkCode"`
	Override  bool
}

type IPAddress struct {
	IP      string `json:"IP"`
	Netmask string `json:"netmask"`
}

// returned by the cluster.get command
type Cluster struct {
	MgmtIP       IPAddress `json:"mgmtIP"`
	InternetVlan string    `json:"internetVlan"`
	Timezone     string    `json:"timezone"`
	DnsServer    string    `json:"DNSserver"`
	DnsDomain    string    `json:"DNSdomain"`
	DnsSearch    string    `json:"DNSsearch"`
	NtpServers   string    `json:"NTPservers"`
	ClusterName  string    `json:"name"`
	Proxy        string    `json:"proxy"`
	LicensingId  string    `json:"id"`
}

type ClusterFilersRaw struct {
	AvailableForReads int64 `json:"availableForReads"`
}

type CifsShare struct {
	ShareName  string `json:"shareName"`
	Export     string `json:"export"`
	Suffix     string `json:"suffix"`
	CreateMask string `json:"create mask"`
	DirMask    string `json:"directory mask"`
}

type UploadStatus struct {
	Status   string `json:"status"`
	Nodename string `json:"nodename"`
	Filename string `json:"filename"`
}

type AdOverride struct {
	Netbios   string `json:"netbios"`
	Fqdn      string `json:"fqdn"`
	Addresses string `json:"addresses"`
}
