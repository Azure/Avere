terraform {
  required_version = ">= 1.0.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.78.0"
    }
  }
  backend "azurerm" {
    key = "3.storage.cache"
  }
}

provider "azurerm" {
  features {}
}

module "global" {
  source = "../global"
}

variable "resourceGroupName" {
  type = string
}

variable "cacheName" {
  type = string
}

variable "hpcCacheEnable" {
  type = bool
}

variable "hpcCacheThroughput" {
  type = string
}

variable "hpcCacheSize" {
  type = string
}

variable "vfxtNodeSize" {
  type = number
}

variable "vfxtNodeCount" {
  type = number
}

variable "vfxtNodeAdminUsername" {
  type = string
}

variable "vfxtNodeSshPublicKey" {
  type = string
}

variable "vfxtControllerAdminUsername" {
  type = string
}

variable "vfxtControllerSshPublicKey" {
  type = string
}

variable "vfxtSupportUploadEnable" {
  type = bool
}

variable "vfxtSupportUploadCompanyName" {
  type = string
}

variable "vfxtProactiveSupportType" {
  type = string
}

variable "vfxtGlobalCustomSettings" {
  type = list(string)
}

variable "storageTargetsNfs" {
  type = list(
    object(
      {
        name              = string
        targetFqdnOrIp    = string
        targetConnections = number
        usageModel        = string
        cachePolicy       = string
        customSettings    = list(string)
        namespaceJunctions = list(
          object(
            {
              namespacePath = string
              nfsExport     = string
              targetPath    = string
            }
          )
        )
      }
    )
  )
}

variable "storageTargetsNfsBlob" {
  type = list(
    object(
      {
        name                 = string
        usageModel           = string
        namespacePath        = string
        storageAccountName   = string
        storageContainerName = string
      }
    )
  )
}

resource "azurerm_resource_group" "cache" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.terraformResourceGroupName
    storage_account_name = module.global.terraformStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "1.network"
  }
}

data "azurerm_virtual_network" "network" {
  name                 = data.terraform_remote_state.network.outputs.virtualNetworkName
  resource_group_name  = data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "cache" {
  name                 = data.terraform_remote_state.network.outputs.virtualNetworkSubnetNameCache
  resource_group_name  = data.terraform_remote_state.network.outputs.resourceGroupName
  virtual_network_name = data.azurerm_virtual_network.network.name
}

data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.terraformResourceGroupName
    storage_account_name = module.global.terraformStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.storage"
  }
}

data "azurerm_resource_group" "storage" {
  name = data.terraform_remote_state.storage.outputs.resourceGroupName
}

locals {
  vfxtControllerAddress   = cidrhost(data.terraform_remote_state.network.outputs.virtualNetworkSubnetAddressSpaceCache[0], 39)
  vfxtVServerFirstAddress = cidrhost(data.terraform_remote_state.network.outputs.virtualNetworkSubnetAddressSpaceCache[0], 40)
  vfxtVServerAddressCount = 20
}

###################################################################################
# HPC Cache - https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview #
###################################################################################

resource "azurerm_hpc_cache" "cache" {
  count               = var.hpcCacheEnable ? 1 : 0
  name                = var.cacheName
  resource_group_name = azurerm_resource_group.cache.name
  location            = azurerm_resource_group.cache.location
  sku_name            = var.hpcCacheThroughput
  cache_size_in_gb    = var.hpcCacheSize
  subnet_id           = data.azurerm_subnet.cache.id
}

resource "azurerm_hpc_cache_nfs_target" "storage" {
  for_each = {
    for x in var.storageTargetsNfs : x.name => x if var.hpcCacheEnable && x.name != ""
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.cache.name
  cache_name          = azurerm_hpc_cache.cache[0].name
  target_host_name    = each.value.targetFqdnOrIp
  usage_model         = each.value.usageModel
  dynamic "namespace_junction" {
    for_each = each.value.namespaceJunctions
    content {
      namespace_path = namespace_junction.value["namespacePath"]
      nfs_export     = namespace_junction.value["nfsExport"]
      target_path    = namespace_junction.value["targetPath"]
    }
  }
}

resource "azurerm_hpc_cache_blob_nfs_target" "storage" {
  for_each = {
    for x in var.storageTargetsNfsBlob : x.name => x if var.hpcCacheEnable && x.name != ""
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.cache.name
  cache_name           = azurerm_hpc_cache.cache[0].name
  storage_container_id = "${data.azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${each.value.storageAccountName}/blobServices/default/containers/${each.value.storageContainerName}"
  usage_model          = each.value.usageModel
  namespace_path       = each.value.namespacePath
}

######################################################################################
# Avere vFXT - https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview #
######################################################################################

data "azurerm_key_vault_secret" "admin_password" {
  name         = module.global.keyVaultSecretNameAdminPassword
  key_vault_id = module.global.keyVaultId
}

module "vfxt_controller" {
  count                          = var.hpcCacheEnable ? 0 : 1
  source                         = "github.com/Azure/Avere/src/terraform/modules/controller3"
  create_resource_group          = false
  resource_group_name            = var.resourceGroupName
  location                       = module.global.regionName
  admin_username                 = var.vfxtControllerAdminUsername
  admin_password                 = data.azurerm_key_vault_secret.admin_password.value
  ssh_key_data                   = var.vfxtControllerSshPublicKey != "" ? var.vfxtControllerSshPublicKey : null
  virtual_network_resource_group = data.azurerm_virtual_network.network.resource_group_name
  virtual_network_name           = data.azurerm_virtual_network.network.name
  virtual_network_subnet_name    = data.azurerm_subnet.cache.name
  static_ip_address              = local.vfxtControllerAddress
  depends_on = [
    azurerm_resource_group.cache
  ]
}

resource "avere_vfxt" "cache" {
  count                           = var.hpcCacheEnable ? 0 : 1
  vfxt_cluster_name               = lower(var.cacheName)
  azure_resource_group            = var.resourceGroupName
  location                        = module.global.regionName
  node_cache_size                 = var.vfxtNodeSize
  vfxt_node_count                 = var.vfxtNodeCount
  azure_network_resource_group    = data.azurerm_virtual_network.network.resource_group_name
  azure_network_name              = data.azurerm_virtual_network.network.name
  azure_subnet_name               = data.azurerm_subnet.cache.name
  controller_address              = module.vfxt_controller[count.index].controller_address
  controller_admin_username       = module.vfxt_controller[count.index].controller_username
  controller_admin_password       = data.azurerm_key_vault_secret.admin_password.value
  vfxt_admin_password             = data.azurerm_key_vault_secret.admin_password.value
  vfxt_ssh_key_data               = var.vfxtNodeSshPublicKey != "" ? var.vfxtNodeSshPublicKey : null
  enable_support_uploads          = var.vfxtSupportUploadEnable
  support_uploads_company_name    = var.vfxtSupportUploadCompanyName
  enable_secure_proactive_support = var.vfxtProactiveSupportType
  global_custom_settings          = var.vfxtGlobalCustomSettings
  vserver_first_ip                = local.vfxtVServerFirstAddress
  vserver_ip_count                = local.vfxtVServerAddressCount
  dynamic "core_filer" {
    for_each = {
      for x in var.storageTargetsNfs : x.name => x if x.name != ""
    }
    content {
      name                      = core_filer.value["name"]
      fqdn_or_primary_ip        = core_filer.value["targetFqdnOrIp"]
      nfs_connection_multiplier = core_filer.value["targetConnections"]
      cache_policy              = core_filer.value["cachePolicy"]
      custom_settings           = core_filer.value["customSettings"]
      dynamic "junction" {
        for_each = core_filer.value["namespaceJunctions"]
        content {
          namespace_path      = junction.value["namespacePath"]
          core_filer_export   = junction.value["nfsExport"]
          export_subdirectory = junction.value["targetPath"]
        }
      }
    }
  }
  depends_on = [
    module.vfxt_controller
  ]
}

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "cacheName" {
  value = var.cacheName
}

output "cacheMountAddresses" {
  value = var.hpcCacheEnable ? azurerm_hpc_cache.cache[0].mount_addresses : avere_vfxt.cache[0].vserver_ip_addresses
}

output "cacheManagementAddress" {
  value = var.hpcCacheEnable ? "" : avere_vfxt.cache[0].vfxt_management_ip
}
