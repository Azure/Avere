terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.75.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.43.0"
    }
    avere = {
      source  = "hashicorp/avere"
      version = "~>1.3.3"
    }
  }
  backend "azurerm" {
    key = "4.File.Cache"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

module "global" {
  source = "../0.Global.Foundation/module"
}

variable "resourceGroupName" {
  type = string
}

variable "cacheName" {
  type = string
}

variable "enableHPCCache" {
  type = string
}

variable "enableDevMode" {
  type = string
}

variable "storageTargetsNfs" {
  type = list(object(
    {
      enable      = bool
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
      namespaceJunctions = list(object(
        {
          storageExport = string
          storagePath   = string
          clientPath    = string
        }
      ))
    }
  ))
}

variable "storageTargetsNfsBlob" {
  type = list(object(
    {
      enable     = bool
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
  ))
}

variable "computeNetwork" {
  type = object(
    {
      enable             = bool
      name               = string
      subnetName         = string
      resourceGroupName  = string
      privateDnsZoneName = string
    }
  )
}

data "azurerm_client_config" "studio" {}

data "azurerm_user_assigned_identity" "studio" {
  name                = module.global.managedIdentity.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault" "studio" {
  count               = module.global.keyVault.enable ? 1 : 0
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "admin_username" {
  count        = module.global.keyVault.enable ? 1 : 0
  name         = module.global.keyVault.secretName.adminUsername
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_key_vault_secret" "admin_password" {
  count        = module.global.keyVault.enable ? 1 : 0
  name         = module.global.keyVault.secretName.adminPassword
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_key_vault_key" "cache_encryption" {
  count        = module.global.keyVault.enable && var.hpcCache.encryption.keyName != "" ? 1 : 0
  name         = var.hpcCache.encryption.keyName != "" ? var.hpcCache.encryption.keyName : module.global.keyVault.keyName.cacheEncryption
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "1.Virtual.Network"
  }
}

data "azurerm_virtual_network" "compute" {
  name                = var.computeNetwork.enable ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = var.computeNetwork.enable ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "cache" {
  name                 = var.computeNetwork.enable ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.cache].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_private_dns_zone" "network" {
  name                = var.computeNetwork.enable ? var.computeNetwork.privateDnsZoneName : data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

resource "azurerm_resource_group" "cache" {
  name     = var.resourceGroupName
  location = module.global.regionNames[0]
}

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

resource "azurerm_private_dns_a_record" "cache" {
  name                = "cache"
  resource_group_name = data.azurerm_private_dns_zone.network.resource_group_name
  zone_name           = data.azurerm_private_dns_zone.network.name
  records             = var.enableHPCCache ? azurerm_hpc_cache.cache[0].mount_addresses : avere_vfxt.cache[0].vserver_ip_addresses
  ttl                 = 300
}

output "resourceGroupName" {
  value = azurerm_resource_group.cache.name
}

output "cacheName" {
  value = var.cacheName
}

output "cacheControllerAddress" {
  value = var.enableHPCCache ? "" : length(avere_vfxt.cache) > 0 ? avere_vfxt.cache[0].controller_address : ""
}

output "cacheManagementAddress" {
  value = var.enableHPCCache ? "" : length(avere_vfxt.cache) > 0 ? avere_vfxt.cache[0].vfxt_management_ip: ""
}

output "cacheMountAddresses" {
  value = var.enableHPCCache && length(azurerm_hpc_cache.cache) > 0 ? azurerm_hpc_cache.cache[0].mount_addresses : length(avere_vfxt.cache) > 0 ? avere_vfxt.cache[0].vserver_ip_addresses : null
}

output "cachePrivateDnsFqdn" {
  value = azurerm_private_dns_a_record.cache.fqdn
}
