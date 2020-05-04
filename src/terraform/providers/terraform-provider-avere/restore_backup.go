// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path"
	"regexp"
	"strings"
)

func GetVfxtTerraform(avereVfxt AvereVfxt, coreFilers []CoreFiler, storageFilers []AzureStorageFiler, customSettings map[string][]string, junctions map[string][]Junction) string {
	mainBody := getVfxtBase()
	vfxtSettings := getVfxtSettings(avereVfxt, customSettings)
	coreFilerJunctions := getCoreFilerJunctions(coreFilers, customSettings, junctions)
	cloudFilerJunctions := getCloudFilerJunctions(storageFilers, customSettings, junctions)
	return fmt.Sprintf(mainBody, vfxtSettings, coreFilerJunctions, cloudFilerJunctions)
}

const (
	UsageModelWriteAround     = "WRITE_AROUND"
	UsageModelReadHeavyInfreq = "READ_HEAVY_INFREQ"
	UsageModelWriteWorkload   = "WRITE_WORKLOAD_15"
)

func getHPCCacheBase() string {
	return `// customize the HPC Cache by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
	
	// hpc cache details
    hpc_cache_resource_group_name = "hpc_cache_resource_group"
    
    // virtual network details
    virtual_network_resource_group = "network_resource_group"
    virtual_network_name = "vnet_name"
    virtual_network_subnet_name = "subnet_name"
}

provider "azurerm" {
    version = "~>2.4.0"
    features {}
}

data "azurerm_subnet" "subnet" {
  name                 = local.virtual_network_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.virtual_network_resource_group
}

resource "azurerm_resource_group" "hpc_cache_rg" {
    name     = local.hpc_cache_resource_group_name
    location = local.location
}

resource "azurerm_hpc_cache" "hpc_cache" {
    location            = azurerm_resource_group.hpc_cache_rg.location
    resource_group_name = azurerm_resource_group.hpc_cache_rg.name
    subnet_id           = data.azurerm_subnet.subnet.id
  
    // HPC Cache Size - 5 allowed sizes (GBs) for the cache
    //     3072
    //     6144
    //    12288
    //    24576
    //    49152
    cache_size_in_gb    = 12288
  
    // HPC Cache Throughput SKU - 3 allowed values for throughput (GB/s) of the cache
    //    Standard_2G
    //    Standard_4G
    //    Standard_8G
    sku_name            = "Standard_2G"
  
    name                = "%s"
}

// filer targets: azurerm_hpc_cache_nfs_target
%s
// storage targets: azurerm_hpc_cache_nfs_target
%s
output "mount_addresses" {
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
}
`
}

func getUsageModel(cachePolicy string) string {
	switch cachePolicy {
	case CachePolicyClientsBypass, CachePolicyIsolatedCloudWorkstation, CachePolicyCollaboratingCloudWorkstation, CachePolicyTransitioningClients:
		return UsageModelWriteAround

	case CachePolicyReadCaching:
		return UsageModelReadHeavyInfreq

	case CachePolicyReadWriteCaching, CachePolicyFullCaching:
		return UsageModelWriteWorkload

	default:
		// write around is the safest usage policy
		return UsageModelWriteAround
	}
}

func getHPCCacheCoreFilerJunctions(coreFilers []CoreFiler, junctions map[string][]Junction) string {
	var sb strings.Builder
	if len(coreFilers) > 0 {
		for _, filer := range coreFilers {
			sb.WriteString(fmt.Sprintf("resource \"azurerm_hpc_cache_nfs_target\" \"%s\" {\n", filer.Name))
			sb.WriteString(fmt.Sprintf("    name                = \"%s\"\n", filer.Name))
			sb.WriteString("    resource_group_name = azurerm_resource_group.hpc_cache_rg.name\n")
			sb.WriteString("    cache_name          = azurerm_hpc_cache.hpc_cache.name\n")
			fqdn := filer.FqdnOrPrimaryIp
			if i := strings.Index(fqdn, " "); i > 0 {
				fqdn = fqdn[:i]
			}
			sb.WriteString(fmt.Sprintf("    target_host_name    = \"%s\"\n", fqdn))
			sb.WriteString(fmt.Sprintf("    usage_model         = \"%s\"\n", getUsageModel(filer.FqdnOrPrimaryIp)))

			if junctions, ok := junctions[filer.Name]; ok {
				for _, junction := range junctions {
					sb.WriteString("    namespace_junction {\n")
					sb.WriteString(fmt.Sprintf("        namespace_path = \"%s\"\n", junction.NameSpacePath))
					sb.WriteString(fmt.Sprintf("        nfs_export     = \"%s\"\n", junction.CoreFilerExport))
					sb.WriteString("    }\n")
				}
			}
			sb.WriteString("}\n")
		}
	}
	return sb.String()
}

func getHPCCacheCloudFilerJunctions(storageFilers []AzureStorageFiler, junctions map[string][]Junction) string {
	var sb strings.Builder
	if len(storageFilers) > 0 {
		for _, filer := range storageFilers {
			// write the azure storage container data source
			name := fmt.Sprintf("%s_%s", filer.AccountName, filer.Container)
			sb.WriteString(fmt.Sprintf("data \"azurerm_storage_container\" \"%s\" {\n", name))
			sb.WriteString(fmt.Sprintf("    name                 = \"%s\"\n", filer.Container))
			sb.WriteString(fmt.Sprintf("    storage_account_name = \"%s\"\n", filer.AccountName))
			sb.WriteString("}\n")
			// write the blob target
			sb.WriteString(fmt.Sprintf("resource \"azurerm_hpc_cache_blob_target\" \"%s\" {\n", name))
			sb.WriteString(fmt.Sprintf("    name                 = \"%s\"\n", filer.AccountName))
			sb.WriteString("    resource_group_name  = azurerm_resource_group.hpc_cache_rg.name\n")
			sb.WriteString("    cache_name           = azurerm_hpc_cache.hpc_cache.name\n")
			sb.WriteString(fmt.Sprintf("    storage_container_id = data.azurerm_storage_container.%s.resource_manager_id\n", name))
			if junctions, ok := junctions[filer.AccountName]; ok && len(junctions) > 0 {
				sb.WriteString(fmt.Sprintf("    namespace_path       = \"%s\"\n", junctions[0].NameSpacePath))
			}
			sb.WriteString("}\n")
		}
	}
	return sb.String()
}

func GetHPCCacheTerraform(avereVfxt AvereVfxt, coreFilers []CoreFiler, storageFilers []AzureStorageFiler, junctions map[string][]Junction) string {
	mainBody := getHPCCacheBase()
	coreFilerJunctions := getHPCCacheCoreFilerJunctions(coreFilers, junctions)
	cloudFilerJunctions := getHPCCacheCloudFilerJunctions(storageFilers, junctions)

	return fmt.Sprintf(mainBody, avereVfxt.AvereVfxtName, coreFilerJunctions, cloudFilerJunctions)
}

func getVfxtBase() string {
	return `// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    // virtual network details
    virtual_network_resource_group = "network_resource_group"
    virtual_network_name = "vnet_name"
    virtual_network_subnet_name = "subnet_name"
    
    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
    // if you are running a locked down network, set controller_add_public_ip to false
    controller_add_public_ip = false
    // advanced scenario: put the resource groups hosting any storage accounts that will be a cloud filer
    alternative_resource_groups = []
}

provider "azurerm" {
    version = "~>2.4.0"
    features {}
}

// the vfxt controller
module "vfxtcontroller" {
    source = "github.com/Azure/Avere/src/terraform/modules/controller"
    resource_group_name = local.vfxt_resource_group_name
    create_resource_group = true
    location = local.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.controller_add_public_ip
    alternative_resource_groups = local.alternative_resource_groups
    
    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = local.virtual_network_name
    virtual_network_subnet_name = local.virtual_network_subnet_name
}

resource "avere_vfxt" "vfxt" {
    controller_address = module.vfxtcontroller.controller_address
    controller_admin_username = module.vfxtcontroller.controller_username
    // ssh key takes precedence over controller password
    controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
    // terraform is not creating the implicit dependency on the controller module
    // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
    // to work around, add the explicit dependency
    depends_on = [module.vfxtcontroller]
    
    // azure information
    location = local.location
    azure_resource_group = local.vfxt_resource_group_name
    azure_network_resource_group = local.network_resource_group_name
    azure_network_name = local.virtual_network_name
    azure_subnet_name = local.virtual_network_subnet_name

    // vFXT settings
%s
    // core filer junctions
%s
    // cloud filer junctions
%s
}

output "controller_username" {
    value = module.vfxtcontroller.controller_username
}

output "controller_address" {
    value = module.vfxtcontroller.controller_address
}

output "ssh_command_with_avere_tunnel" {
    value = "ssh -L443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
}

output "management_ip" {
    value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
    value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}
`
}

func getVfxtSettings(avereVfxt AvereVfxt, customSettings map[string][]string) string {
	var sb strings.Builder
	sb.WriteString("    vfxt_admin_password = \"REPLACE\"\n")
	sb.WriteString("    // node count may be from 3 to 16\n")
	sb.WriteString(fmt.Sprintf("    vfxt_node_count = %d\n", avereVfxt.NodeCount))
	sb.WriteString("    // cache size per node may be 4096 (4TB) or 1024 (1TB)\n")
	sb.WriteString(fmt.Sprintf("    node_cache_size = %d\n", avereVfxt.NodeCacheSize))
	if len(avereVfxt.AvereVfxtName) > 0 {
		sb.WriteString(fmt.Sprintf("    vfxt_cluster_name = \"%s\"\n", avereVfxt.AvereVfxtName))
	}
	if len(avereVfxt.NtpServers) > 0 {
		sb.WriteString(fmt.Sprintf("    ntp_servers = \"%s\"\n", avereVfxt.NtpServers))
	}
	if len(avereVfxt.Timezone) > 0 {
		sb.WriteString(fmt.Sprintf("    timezone = \"%s\"\n", avereVfxt.Timezone))
	}
	if len(avereVfxt.DnsServer) > 0 {
		sb.WriteString(fmt.Sprintf("    dns_server = \"%s\"\n", avereVfxt.DnsServer))
	}
	if len(avereVfxt.DnsDomain) > 0 {
		sb.WriteString(fmt.Sprintf("    dns_domain = \"%s\"\n", avereVfxt.DnsDomain))
	}
	if len(avereVfxt.DnsSearch) > 0 {
		sb.WriteString(fmt.Sprintf("    dns_search = \"%s\"\n", avereVfxt.DnsSearch))
	}
	if len(avereVfxt.ProxyUri) > 0 {
		sb.WriteString(fmt.Sprintf("    proxy_uri = \"%s\"\n", avereVfxt.ProxyUri))
	}
	if len(avereVfxt.ClusterProxyUri) > 0 {
		sb.WriteString(fmt.Sprintf("    cluster_proxy_uri = \"%s\"\n", avereVfxt.ClusterProxyUri))
	}

	if settings, ok := customSettings[GlobalCustomSettingsKey]; ok {
		sb.WriteString("    global_custom_settings = [\n")
		for _, s := range settings {
			sb.WriteString(fmt.Sprintf("        \"%s\",\n", s))
		}
		sb.WriteString("    ]\n")
	}

	if settings, ok := customSettings[VserverCustomSettingsKey]; ok {
		sb.WriteString("    vserver_settings = [\n")
		for _, s := range settings {
			sb.WriteString(fmt.Sprintf("        \"%s\",\n", s))
		}
		sb.WriteString("    ]\n")
	}

	sb.WriteString("    // support uploads enable Avere support staff to provide the best possible support\n")
	sb.WriteString("    // by setting to true, you agree to the privacy policy https://privacy.microsoft.com/en-us/privacystatement\n")
	sb.WriteString("    enable_support_uploads = false\n")

	return sb.String()
}

func getCoreFilerJunctions(coreFilers []CoreFiler, customSettings map[string][]string, junctions map[string][]Junction) string {
	var sb strings.Builder
	for _, coreFiler := range coreFilers {
		sb.WriteString("    core_filer {\n")
		sb.WriteString(fmt.Sprintf("        name = \"%s\"\n", coreFiler.Name))
		sb.WriteString(fmt.Sprintf("        fqdn_or_primary_ip = \"%s\"\n", coreFiler.FqdnOrPrimaryIp))
		sb.WriteString(fmt.Sprintf("        cache_policy = \"%s\"\n", coreFiler.CachePolicy))
		if settings, ok := customSettings[coreFiler.Name]; ok {
			sb.WriteString("        custom_settings = [\n")
			for _, s := range settings {
				sb.WriteString(fmt.Sprintf("            \"%s\",\n", s))
			}
			sb.WriteString("        ]\n")
		}
		if junctions, ok := junctions[coreFiler.Name]; ok {
			for _, junction := range junctions {
				sb.WriteString("        junction {\n")
				sb.WriteString(fmt.Sprintf("            namespace_path = \"%s\"\n", junction.NameSpacePath))
				sb.WriteString(fmt.Sprintf("            core_filer_export = \"%s\"\n", junction.CoreFilerExport))
				sb.WriteString("        }\n")
			}
		}
		sb.WriteString("    }\n")
	}

	return sb.String()
}

func getCloudFilerJunctions(storageFilers []AzureStorageFiler, customSettings map[string][]string, junctions map[string][]Junction) string {
	var sb strings.Builder
	for _, storageFiler := range storageFilers {
		sb.WriteString("    azure_storage_filer  {\n")
		sb.WriteString(fmt.Sprintf("        account_name  = \"%s\"\n", storageFiler.AccountName))
		sb.WriteString(fmt.Sprintf("        container_name = \"%s\"\n", storageFiler.Container))
		if settings, ok := customSettings[storageFiler.AccountName]; ok {
			sb.WriteString("    custom_settings = [\n")
			for _, s := range settings {
				sb.WriteString(fmt.Sprintf("            \"%s\",\n", s))
			}
			sb.WriteString("    ]\n")
		}
		if junctions, ok := junctions[storageFiler.AccountName]; ok && len(junctions) > 0 {
			sb.WriteString(fmt.Sprintf("        junction_namespace_path = \"%s\"\n", junctions[0].NameSpacePath))
		}
		sb.WriteString("    }\n")
	}
	return sb.String()
}

const (
	VfxtTerraformFilename     = "vfxt-main.tf"
	HPCCacheTerraformFilename = "hpccache-main.tf"

	VfxtMainConfig           = "1-config_restore.sh"
	VfxtMassesConfig         = "masses.txt"
	VfxtCustomSettingsConfig = "original_custom_settings.txt"

	GlobalCustomSettingsKey  = "global"
	VserverCustomSettingsKey = "vserver"
)

func GetVfxtBackupFiles(vfxtBackupDirectory string) (mainConfigFile string, massesConfigFile string, customSettingsConfigFile string) {
	mainConfigFile = path.Join(vfxtBackupDirectory, VfxtMainConfig)
	massesConfigFile = path.Join(vfxtBackupDirectory, VfxtMassesConfig)
	customSettingsConfigFile = path.Join(vfxtBackupDirectory, VfxtCustomSettingsConfig)
	return mainConfigFile, massesConfigFile, customSettingsConfigFile
}

func IsVfxtBackupDir(vfxtBackupDirectory string) bool {
	mainConfigFile, massesConfigFile, customSettingsConfigFile := GetVfxtBackupFiles(vfxtBackupDirectory)
	if _, err := os.Stat(mainConfigFile); err != nil {
		return false
	}
	if _, err := os.Stat(massesConfigFile); err != nil {
		return false
	}
	if _, err := os.Stat(customSettingsConfigFile); err != nil {
		return false
	}
	return true
}

func GetMasses(vfxtBackupDirectory string) (map[string]string, error) {
	_, massesFile, _ := GetVfxtBackupFiles(vfxtBackupDirectory)
	massResults := make(map[string]string)
	file, err := os.Open(massesFile)
	if err != nil {
		return massResults, fmt.Errorf("error opening file '%s': '%v'", massesFile, err)
	}
	defer file.Close()
	massRegEx := regexp.MustCompile(`(mass\d*):(.*)`)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if scanner.Err() != nil {
			return massResults, fmt.Errorf("error scanning file '%s': '%v'", massesFile, scanner.Err())
		}
		line := scanner.Text()
		matches := massRegEx.FindStringSubmatch(line)
		if len(matches) == 3 && len(matches[1]) > 0 && len(matches[2]) > 0 {
			mass := matches[1]
			filer := matches[2]
			massResults[mass] = filer
		}
	}

	return massResults, nil
}

func GetCustomSettings(vfxtBackupDirectory string, massToFilerName map[string]string) (map[string][]string, error) {
	_, _, customSettingsConfigFile := GetVfxtBackupFiles(vfxtBackupDirectory)

	results := make(map[string][]string)
	results[GlobalCustomSettingsKey] = []string{}
	results[VserverCustomSettingsKey] = []string{}

	file, err := os.Open(customSettingsConfigFile)
	if err != nil {
		return results, fmt.Errorf("error opening file '%s': '%v'", customSettingsConfigFile, err)
	}
	defer file.Close()
	massRegEx := regexp.MustCompile(`averecmd support.setCustomSetting ([^ ]*) ([^ ]*) ([^ "]*)`)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if scanner.Err() != nil {
			return results, fmt.Errorf("error scanning file '%s': '%v'", customSettingsConfigFile, scanner.Err())
		}
		line := scanner.Text()
		matches := massRegEx.FindStringSubmatch(line)
		if len(matches) == 4 && len(matches[1]) > 0 && len(matches[2]) > 0 && len(matches[3]) > 0 {
			setting := matches[1]
			checkcode := matches[2]
			settingValue := matches[3]
			if strings.Index(matches[1], "mass") == 0 {
				// this is a mass
				mass := setting[:strings.Index(setting, ".")]
				filerName := ""
				if v, ok := massToFilerName[mass]; ok {
					filerName = v
				} else {
					return results, fmt.Errorf("missing filer mapping for massName '%s'", mass)
				}
				customSetting := fmt.Sprintf("%s %s %s", setting[strings.Index(setting, ".")+1:], checkcode, settingValue)
				if _, ok := results[filerName]; !ok {
					results[filerName] = []string{}
				}
				results[filerName] = append(results[filerName], customSetting)
			} else if strings.Index(matches[1], "vserver") == 0 {
				// this is a vserver
				customSetting := fmt.Sprintf("%s %s %s", setting[strings.Index(setting, ".")+1:], checkcode, settingValue)
				results[VserverCustomSettingsKey] = append(results[VserverCustomSettingsKey], customSetting)
			} else {
				// this is a global setting
				customSetting := fmt.Sprintf("%s %s %s", setting, checkcode, settingValue)
				results[GlobalCustomSettingsKey] = append(results[GlobalCustomSettingsKey], customSetting)
			}
		}
	}

	return results, nil
}

func GetBackupLines(vfxtBackupDirectory string) ([]string, error) {
	mainConfigFile, _, _ := GetVfxtBackupFiles(vfxtBackupDirectory)
	results := make([]string, 0)
	file, err := os.Open(mainConfigFile)
	if err != nil {
		return results, fmt.Errorf("error opening file '%s': '%v'", mainConfigFile, err)
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if scanner.Err() != nil {
			return results, fmt.Errorf("error scanning file '%s': '%v'", mainConfigFile, scanner.Err())
		}
		results = append(results, scanner.Text())
	}
	return results, nil
}

func FillAvereVfxtFromBackupFile(lines []string) (AvereVfxt, error) {
	avereVfxt := AvereVfxt{
		EnableSupportUploads: false, // customer always chooses to enable support uploads
		NodeCount:            3,
		NodeCacheSize:        4096,
	}

	isClusterModify := false
	clusterModifyStr := ""
	for _, line := range lines {

		// handle averecmd cluster.modify
		if strings.Index(line, "averecmd cluster.modify") >= 0 {
			isClusterModify = true
		}
		if isClusterModify {
			openIndex := strings.Index(line, "\"{")
			closeIndex := strings.Index(line, "}\"")
			if openIndex > 0 && closeIndex > 0 {
				clusterModifyStr = line[openIndex+1 : closeIndex+1]
				isClusterModify = false
			} else if openIndex > 0 {
				clusterModifyStr = line[openIndex+1:]
			} else if closeIndex > 0 {
				clusterModifyStr += line[:closeIndex+1]
				isClusterModify = false
			} else {
				clusterModifyStr += line
			}
			if isClusterModify == false {
				var cluster Cluster
				if err := json.Unmarshal([]byte(strings.ReplaceAll(clusterModifyStr, "'", "\"")), &cluster); err != nil {
					return avereVfxt, fmt.Errorf("unable to parse json string")
				}
				avereVfxt.AvereVfxtName = cluster.ClusterName
				avereVfxt.NtpServers = cluster.NtpServers
				avereVfxt.Timezone = cluster.Timezone
				avereVfxt.DnsServer = cluster.DnsServer
				avereVfxt.DnsDomain = cluster.DnsDomain
				avereVfxt.DnsSearch = cluster.DnsSearch
				if len(cluster.Proxy) > 0 {
					avereVfxt.ProxyUri = cluster.Proxy
					avereVfxt.ClusterProxyUri = cluster.Proxy
				}
			}
		}
	}
	return avereVfxt, nil
}

func FillCoreFilers(lines []string) ([]CoreFiler, error) {
	results := make([]CoreFiler, 0)

	coreFilerRegEx := regexp.MustCompile(`averecmd corefiler.create\s*"([^"]*)"\s*"([^"]*)".*'cachePolicy':'([^']*)'`)

	for _, line := range lines {
		coreFilerMatches := coreFilerRegEx.FindStringSubmatch(line)
		if len(coreFilerMatches) > 3 && len(coreFilerMatches[1]) > 0 && len(coreFilerMatches[2]) > 0 && len(coreFilerMatches[3]) > 0 {
			filername := coreFilerMatches[1]
			address := coreFilerMatches[2]
			cachePolicy := coreFilerMatches[3]
			coreFiler := CoreFiler{
				Name:            filername,
				FqdnOrPrimaryIp: address,
				CachePolicy:     cachePolicy,
			}
			results = append(results, coreFiler)
		}
	}

	return results, nil
}

func FillAzureStorageFilers(lines []string) ([]AzureStorageFiler, map[string]string, error) {
	storageFilers := make([]AzureStorageFiler, 0)
	storageFilerNametoAccountMapping := make(map[string]string)

	storageFilerRegEx := regexp.MustCompile(`averecmd corefiler.createCloudFiler\s*"([^"]*).*'bucket':'[^/]*/?([^']*)'.*'networkName':'([^\.]*)`)

	for _, line := range lines {
		storageFilerMatches := storageFilerRegEx.FindStringSubmatch(line)
		if len(storageFilerMatches) > 3 && len(storageFilerMatches[1]) > 0 && len(storageFilerMatches[2]) > 0 && len(storageFilerMatches[3]) > 0 {
			originalName := storageFilerMatches[1]
			container := storageFilerMatches[2]
			accountName := storageFilerMatches[3]
			azureStorageFiler := AzureStorageFiler{
				AccountName: accountName,
				Container:   container,
			}
			storageFilers = append(storageFilers, azureStorageFiler)
			storageFilerNametoAccountMapping[originalName] = accountName
		}
	}

	return storageFilers, storageFilerNametoAccountMapping, nil
}

func FillJunctions(lines []string, storageFilerNametoAccountMapping map[string]string) (map[string][]Junction, error) {
	junctions := make(map[string][]Junction)

	junctionRegEx := regexp.MustCompile(`averecmd vserver.addJunction\s*[^\s]*\s([^\s]*)\s([^\s]*)\s([^\s]*)`)

	for _, line := range lines {
		junctionMatches := junctionRegEx.FindStringSubmatch(line)
		if len(junctionMatches) > 3 && len(junctionMatches[1]) > 0 && len(junctionMatches[2]) > 0 && len(junctionMatches[3]) > 0 {
			nameSpacePath := junctionMatches[1]
			coreFilerName := junctionMatches[2]
			if v, ok := storageFilerNametoAccountMapping[coreFilerName]; ok {
				coreFilerName = v
			}
			coreFilerExport := junctionMatches[3]
			junction := Junction{
				NameSpacePath:   nameSpacePath,
				CoreFilerName:   coreFilerName,
				CoreFilerExport: coreFilerExport,
			}
			if _, ok := junctions[junction.CoreFilerName]; !ok {
				junctions[junction.CoreFilerName] = make([]Junction, 0)
			}
			junctions[junction.CoreFilerName] = append(junctions[junction.CoreFilerName], junction)
		}
	}
	return junctions, nil
}

func GetModels(vfxtBackupDirectory string) (avereVfxt AvereVfxt, coreFilers []CoreFiler, storageFilers []AzureStorageFiler, customSettings map[string][]string, junctions map[string][]Junction, err error) {
	masses, err := GetMasses(vfxtBackupDirectory)
	if err != nil {
		return avereVfxt, coreFilers, storageFilers, customSettings, junctions, err
	}

	if customSettings, err = GetCustomSettings(vfxtBackupDirectory, masses); err != nil {
		return avereVfxt, coreFilers, storageFilers, customSettings, junctions, err
	}

	backupFileLines, err := GetBackupLines(vfxtBackupDirectory)
	if err != nil {
		return avereVfxt, coreFilers, storageFilers, customSettings, junctions, err
	}

	if avereVfxt, err = FillAvereVfxtFromBackupFile(backupFileLines); err != nil {
		return avereVfxt, coreFilers, storageFilers, customSettings, junctions, err
	}

	if coreFilers, err = FillCoreFilers(backupFileLines); err != nil {
		return avereVfxt, coreFilers, storageFilers, customSettings, junctions, err
	}

	var storageFilerNametoAccountMapping map[string]string
	if storageFilers, storageFilerNametoAccountMapping, err = FillAzureStorageFilers(backupFileLines); err != nil {
		return avereVfxt, coreFilers, storageFilers, customSettings, junctions, err
	}

	if junctions, err = FillJunctions(backupFileLines, storageFilerNametoAccountMapping); err != nil {
		return avereVfxt, coreFilers, storageFilers, customSettings, junctions, err
	}

	return avereVfxt, coreFilers, storageFilers, customSettings, junctions, nil
}

func WriteTerraformFiles(vfxtBackupDirectory string) error {
	avereVfxt, coreFilers, storageFilers, customSettings, junctions, err := GetModels(vfxtBackupDirectory)
	if err != nil {
		return nil
	}

	tf := GetVfxtTerraform(avereVfxt, coreFilers, storageFilers, customSettings, junctions)

	file, err := os.OpenFile(VfxtTerraformFilename, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("error opening file '%s': '%v'", VfxtTerraformFilename, err)
	}
	if _, err := file.Write([]byte(tf)); err != nil {
		file.Close()
		return fmt.Errorf("error writing contents to '%s': '%v'", VfxtTerraformFilename, err)
	}
	file.Close()
	fmt.Printf("'%s' written, derived from backup '%s'", VfxtTerraformFilename, vfxtBackupDirectory)

	tf = GetHPCCacheTerraform(avereVfxt, coreFilers, storageFilers, junctions)

	file, err = os.OpenFile(HPCCacheTerraformFilename, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("error opening file '%s': '%v'", HPCCacheTerraformFilename, err)
	}
	if _, err := file.Write([]byte(tf)); err != nil {
		file.Close()
		return fmt.Errorf("error writing contents to '%s': '%v'", HPCCacheTerraformFilename, err)
	}
	file.Close()
	fmt.Printf("'%s' written, derived from backup '%s'", HPCCacheTerraformFilename, vfxtBackupDirectory)

	return nil
}
