terraform {
  required_version = ">= 1.1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.5.0"
    }
    avere = {
      source  = "hashicorp/avere"
      version = "~>1.3.2"
    }
  }
  backend "azurerm" {
    key = "4.storage.cache"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

module "global" {
  source = "../0.global"
}

variable "resourceGroupName" {
  type = string
}

variable "cacheName" {
  type = string
}

variable "enableHpcCache" {
  type = bool
}

variable "hpcCache" {
  type = object(
    {
      throughput = string
      size       = number
      mtuSize    = number
      ntpHost    = string
    }
  )
}

variable "vfxtCache" {
  type = object(
    {
      cluster = object(
        {
          nodeSize       = number
          nodeCount      = number
          nodeImageId    = string
          adminUsername  = string
          sshPublicKey   = string
          customSettings = list(string)
        }
      )
      controller = object(
        {
          adminUsername = string
          sshPublicKey  = string
        }
      )
      support = object(
        {
          companyName        = string
          enableProactive    = string
          enableLogUpload    = bool
          enableRollingTrace = bool
        }
      )
    }
  )
}

variable "storageTargetsNfs" {
  type = list(
    object(
      {
        name        = string
        storageHost = string
        hpcCache = object(
          {
            usageModel = string
          }
        )
        vfxtCache = object(
          {
            cachePolicy    = string
            nfsConnections = number
            customSettings = list(string)
          }
        )
        namespaceJunctions = list(
          object(
            {
              storageExport = string
              storagePath   = string
              clientPath    = string
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
        name       = string
        clientPath = string
        usageModel = string
        storage = object(
          {
            resourceGroupName = string
            accountName       = string
            containerName     = string
          }
        )
      }
    )
  )
}

variable "virtualNetwork" {
  type = object(
    {
      name               = string
      subnetName         = string
      resourceGroupName  = string
      privateDns = object(
        {
          zoneName               = string
          enableAutoRegistration = bool 
        }
      )
    }
  )
}

data "azurerm_client_config" "current" {}

data "terraform_remote_state" "network" {
  count   = local.useRemoteStateNetwork
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
  }
}

data "azurerm_virtual_network" "network" {
  name                 = var.virtualNetwork.name != "" ? var.virtualNetwork.name : data.terraform_remote_state.network[0].outputs.virtualNetwork.name
  resource_group_name  = var.virtualNetwork.name != "" ? var.virtualNetwork.resourceGroupName : data.terraform_remote_state.network[0].outputs.resourceGroupName
}

data "azurerm_subnet" "cache" {
  name                 = var.virtualNetwork.name != "" ? var.virtualNetwork.subnetName : data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets[data.terraform_remote_state.network[0].outputs.virtualNetworkSubnetIndex.cache].name
  resource_group_name  = var.virtualNetwork.name != "" ? var.virtualNetwork.resourceGroupName : data.terraform_remote_state.network[0].outputs.resourceGroupName
  virtual_network_name = var.virtualNetwork.name != "" ? var.virtualNetwork.name : data.terraform_remote_state.network[0].outputs.virtualNetwork.name
}

data "azurerm_private_dns_zone" "network" {
  count                = local.useRemoteStateNetwork
  name                 = data.terraform_remote_state.network[0].outputs.virtualNetworkPrivateDns.zoneName
  resource_group_name  = data.terraform_remote_state.network[0].outputs.resourceGroupName
}

locals {
  useRemoteStateNetwork   = var.virtualNetwork.name != "" ? 0 : 1
  vfxtControllerAddress   = var.virtualNetwork.name != "" ? "" : cidrhost(data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets[data.terraform_remote_state.network[0].outputs.virtualNetworkSubnetIndex.cache].addressSpace[0], 39)
  vfxtVServerFirstAddress = var.virtualNetwork.name != "" ? "" : cidrhost(data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets[data.terraform_remote_state.network[0].outputs.virtualNetworkSubnetIndex.cache].addressSpace[0], 40)
  vfxtVServerAddressCount = 16
  deployPrivateDnsZone    = var.virtualNetwork.privateDns.zoneName != "" ? 1 : 0
  updatePrivateDnsZone    = var.virtualNetwork.privateDns.zoneName != "" ? 1 : local.useRemoteStateNetwork
}

resource "azurerm_resource_group" "cache" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

###################################################################################
# HPC Cache (https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview) #
###################################################################################

resource "azurerm_hpc_cache" "cache" {
  count               = var.enableHpcCache ? 1 : 0
  name                = var.cacheName
  resource_group_name = azurerm_resource_group.cache.name
  location            = azurerm_resource_group.cache.location
  subnet_id           = data.azurerm_subnet.cache.id
  sku_name            = var.hpcCache.throughput
  cache_size_in_gb    = var.hpcCache.size
  mtu                 = var.hpcCache.mtuSize
  ntp_server          = var.hpcCache.ntpHost
}

resource "azurerm_hpc_cache_nfs_target" "storage" {
  for_each = {
    for x in var.storageTargetsNfs : x.name => x if var.enableHpcCache && x.name != ""
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.cache.name
  cache_name          = azurerm_hpc_cache.cache[0].name
  target_host_name    = each.value.storageHost
  usage_model         = each.value.hpcCache.usageModel
  dynamic "namespace_junction" {
    for_each = each.value.namespaceJunctions
    content {
      nfs_export     = namespace_junction.value["storageExport"]
      target_path    = namespace_junction.value["storagePath"]
      namespace_path = namespace_junction.value["clientPath"]
    }
  }
}

resource "azurerm_hpc_cache_blob_nfs_target" "storage" {
  for_each = {
    for x in var.storageTargetsNfsBlob : x.name => x if var.enableHpcCache && x.name != ""
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.cache.name
  cache_name           = azurerm_hpc_cache.cache[0].name
  storage_container_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}/blobServices/default/containers/${each.value.storage.containerName}"
  usage_model          = each.value.usageModel
  namespace_path       = each.value.clientPath
}

######################################################################################
# Avere vFXT (https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview) #
######################################################################################

data "azurerm_key_vault" "vault" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = module.global.keyVaultSecretNameAdminPassword
  key_vault_id = data.azurerm_key_vault.vault.id
}

module "vfxt_controller" {
  count                          = var.enableHpcCache ? 0 : 1
  source                         = "github.com/Azure/Avere/src/terraform/modules/controller3"
  create_resource_group          = false
  resource_group_name            = var.resourceGroupName
  location                       = module.global.regionName
  admin_username                 = var.vfxtCache.controller.adminUsername
  admin_password                 = data.azurerm_key_vault_secret.admin_password.value
  ssh_key_data                   = var.vfxtCache.controller.sshPublicKey != "" ? var.vfxtCache.controller.sshPublicKey : null
  virtual_network_name           = data.azurerm_virtual_network.network.name
  virtual_network_resource_group = data.azurerm_virtual_network.network.resource_group_name
  virtual_network_subnet_name    = data.azurerm_subnet.cache.name
  static_ip_address              = local.vfxtControllerAddress
  depends_on = [
    azurerm_resource_group.cache
  ]
}

resource "avere_vfxt" "cache" {
  count                           = var.enableHpcCache ? 0 : 1
  vfxt_cluster_name               = lower(var.cacheName)
  azure_resource_group            = var.resourceGroupName
  location                        = module.global.regionName
  node_cache_size                 = var.vfxtCache.cluster.nodeSize
  vfxt_node_count                 = var.vfxtCache.cluster.nodeCount
  image_id                        = var.vfxtCache.cluster.nodeImageId
  azure_network_name              = data.azurerm_virtual_network.network.name
  azure_network_resource_group    = data.azurerm_virtual_network.network.resource_group_name
  azure_subnet_name               = data.azurerm_subnet.cache.name
  controller_address              = module.vfxt_controller[count.index].controller_address
  controller_admin_username       = module.vfxt_controller[count.index].controller_username
  controller_admin_password       = data.azurerm_key_vault_secret.admin_password.value
  vfxt_admin_password             = data.azurerm_key_vault_secret.admin_password.value
  vfxt_ssh_key_data               = var.vfxtCache.cluster.sshPublicKey != "" ? var.vfxtCache.cluster.sshPublicKey : null
  support_uploads_company_name    = var.vfxtCache.support.companyName
  enable_secure_proactive_support = var.vfxtCache.support.enableProactive
  enable_support_uploads          = var.vfxtCache.support.enableLogUpload
  enable_rolling_trace_data       = var.vfxtCache.support.enableRollingTrace
  global_custom_settings          = var.vfxtCache.cluster.customSettings
  vserver_first_ip                = local.vfxtVServerFirstAddress
  vserver_ip_count                = local.vfxtVServerAddressCount
  dynamic "core_filer" {
    for_each = {
      for x in var.storageTargetsNfs : x.name => x if x.name != ""
    }
    content {
      name                      = core_filer.value["name"]
      fqdn_or_primary_ip        = core_filer.value["storageHost"]
      cache_policy              = core_filer.value["vfxtCache"].cachePolicy
      nfs_connection_multiplier = core_filer.value["vfxtCache"].nfsConnections
      custom_settings           = core_filer.value["vfxtCache"].customSettings
      dynamic "junction" {
        for_each = core_filer.value["namespaceJunctions"]
        content {
          core_filer_export   = junction.value["storageExport"]
          export_subdirectory = junction.value["storagePath"]
          namespace_path      = junction.value["clientPath"]
        }
      }
    }
  }
  depends_on = [
    module.vfxt_controller
  ]
}

################################################################################# 
# Private DNS (https://docs.microsoft.com/en-us/azure/dns/private-dns-overview) #
################################################################################# 

resource "azurerm_private_dns_zone" "network" {
  count               = local.deployPrivateDnsZone
  name                = var.virtualNetwork.privateDns.zoneName
  resource_group_name = azurerm_resource_group.cache.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network" {
  count                 = local.deployPrivateDnsZone
  name                  = var.virtualNetwork.name
  resource_group_name   = azurerm_resource_group.cache.name
  private_dns_zone_name = azurerm_private_dns_zone.network[0].name
  virtual_network_id    = data.azurerm_virtual_network.network.id
  registration_enabled  = var.virtualNetwork.privateDns.enableAutoRegistration
}

resource "azurerm_private_dns_a_record" "cache" {
  count               = local.updatePrivateDnsZone
  name                = "cache"
  resource_group_name = local.useRemoteStateNetwork == 0 ? azurerm_private_dns_zone.network[0].resource_group_name : data.azurerm_private_dns_zone.network[0].resource_group_name
  zone_name           = local.useRemoteStateNetwork == 0 ? azurerm_private_dns_zone.network[0].name : data.azurerm_private_dns_zone.network[0].name
  records             = var.enableHpcCache ? azurerm_hpc_cache.cache[0].mount_addresses : avere_vfxt.cache[0].vserver_ip_addresses
  ttl                 = 300
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

output "cacheControllerAddress" {
  value = var.enableHpcCache ? "" : avere_vfxt.cache[0].controller_address
}

output "cacheManagementAddress" {
  value = var.enableHpcCache ? "" : avere_vfxt.cache[0].vfxt_management_ip
}

output "cacheMountAddresses" {
  value = var.enableHpcCache ? azurerm_hpc_cache.cache[0].mount_addresses : avere_vfxt.cache[0].vserver_ip_addresses
}

output "cachePrivateDnsFqdn" {
  value = local.updatePrivateDnsZone == 0 ? "" : azurerm_private_dns_a_record.cache[0].fqdn
}
