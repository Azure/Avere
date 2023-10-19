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
  type = bool
}

variable "enablePerRegion" {
  type = bool
}

variable "storageTargetsNfs" {
  type = list(object({
    enable      = bool
    name        = string
    storageHost = string
    hpcCache = object({
      usageModel = string
    })
    vfxtCache = object({
      cachePolicy    = string
      nfsConnections = number
      customSettings = list(string)
    })
    namespaceJunctions = list(object({
      storageExport = string
      storagePath   = string
      clientPath    = string
    }))
  }))
}

variable "storageTargetsNfsBlob" {
  type = list(object({
    enable     = bool
    name       = string
    clientPath = string
    usageModel = string
    storage = object({
      resourceGroupName = string
      accountName       = string
      containerName     = string
    })
  }))
}

variable "existingNetwork" {
  type = object({
    enable             = bool
    name               = string
    subnetName         = string
    resourceGroupName  = string
    privateDnsZoneName = string
  })
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
  count        = module.global.keyVault.enable && var.hpcCache.encryption.enable ? 1 : 0
  name         = module.global.keyVault.keyName.cacheEncryption
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

data "azurerm_private_dns_zone" "studio" {
  name                = var.existingNetwork.enable ? var.existingNetwork.privateDnsZoneName : data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = var.existingNetwork.enable ? var.existingNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

locals {
  regionNames = var.existingNetwork.enable || !var.enablePerRegion ? [module.global.regionName] : [
    for virtualNetwork in data.terraform_remote_state.network.outputs.virtualNetworks : virtualNetwork.regionName
  ]
  virtualNetworks = distinct(!var.enablePerRegion ? [
    for i in range(length(data.terraform_remote_state.network.outputs.virtualNetworks)) : {
      id         = data.terraform_remote_state.network.outputs.virtualNetwork.id
      regionName = data.terraform_remote_state.network.outputs.virtualNetwork.regionName
    }
  ] : [
    for virtualNetwork in data.terraform_remote_state.network.outputs.virtualNetworks : {
      id         = virtualNetwork.id
      regionName = virtualNetwork.regionName
    }
  ])
}

resource "azurerm_resource_group" "cache_regions" {
  count    = length(local.regionNames)
  name     = "${var.resourceGroupName}.${local.regionNames[count.index]}"
  location = local.regionNames[count.index]
}

output "resourceGroups" {
  value = [
    for resourceGroup in azurerm_resource_group.cache_regions : {
      id   = resourceGroup.id
      name = resourceGroup.name
    }
  ]
}
