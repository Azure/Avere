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
  }
  backend "azurerm" {
    key = "6.Render.Farm"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine_scale_set {
      force_delete                  = false
      roll_instances_when_required  = true
      scale_to_zero_before_deletion = true
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
}

module "global" {
  source = "../0.Global.Foundation/module"
}

variable "resourceGroupName" {
  type = string
}

variable "activeDirectory" {
  type = object({
    enable           = bool
    domainName       = string
    domainServerName = string
    orgUnitPath      = string
    adminUsername    = string
    adminPassword    = string
  })
}

variable "existingNetwork" {
  type = object({
    enable            = bool
    name              = string
    subnetNameFarm    = string
    subnetNameAI      = string
    resourceGroupName = string
  })
}

variable "existingStorage" {
  type = object({
    enable            = bool
    name              = string
    resourceGroupName = string
    fileShareName     = string
  })
}

data "http" "client_address" {
  url = "https://api.ipify.org?format=json"
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

data "azurerm_log_analytics_workspace" "monitor" {
  count               = module.global.monitor.enable ? 1 : 0
  name                = module.global.monitor.name
  resource_group_name = module.global.resourceGroupName
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

data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "3.File.Storage"
  }
}

data "azurerm_application_insights" "studio" {
  count               = module.global.monitor.enable ? 1 : 0
  name                = module.global.monitor.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_virtual_network" "studio" {
  name                = var.existingNetwork.enable ? var.existingNetwork.name : data.terraform_remote_state.network.outputs.virtualNetwork.name
  resource_group_name = var.existingNetwork.enable ? var.existingNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.virtualNetwork.resourceGroupName
}

data "azurerm_subnet" "farm" {
  name                 = var.existingNetwork.enable ? var.existingNetwork.subnetNameFarm : data.terraform_remote_state.network.outputs.virtualNetwork.subnets[data.terraform_remote_state.network.outputs.virtualNetwork.subnetIndex.farm].name
  resource_group_name  = data.azurerm_virtual_network.studio.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.studio.name
}

data "azurerm_subnet" "ai" {
  name                 = var.existingNetwork.enable ? var.existingNetwork.subnetNameAI : data.terraform_remote_state.network.outputs.virtualNetwork.subnets[data.terraform_remote_state.network.outputs.virtualNetwork.subnetIndex.ai].name
  resource_group_name  = data.azurerm_virtual_network.studio.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.studio.name
}

data "azurerm_private_dns_zone" "studio" {
  name                = data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.studio.resource_group_name
}

data "azurerm_storage_account" "studio" {
  name                = var.existingStorage.enable ? var.existingStorage.name : data.terraform_remote_state.storage.outputs.blobStorageAccount.name
  resource_group_name = var.existingStorage.enable ? var.existingStorage.resourceGroupName : data.terraform_remote_state.storage.outputs.resourceGroupName
}

data "azurerm_storage_share" "studio" {
  name                 = var.existingStorage.enable ? var.existingStorage.fileShareName : data.terraform_remote_state.storage.outputs.blobStorageAccount.fileShares[0].name
  storage_account_name = data.azurerm_storage_account.studio.name
}

resource "azurerm_resource_group" "farm" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

output "resourceGroupName" {
  value = azurerm_resource_group.farm.name
}
