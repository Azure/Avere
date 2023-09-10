terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.72.0"
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
  }
}

module "global" {
  source = "../0.Global.Foundation/module"
}

variable "resourceGroupName" {
  type = string
}

variable "computeNetwork" {
  type = object(
    {
      name              = string
      subnetName        = string
      resourceGroupName = string
    }
  )
}

variable "storageAccount" {
  type = object(
    {
      name               = string
      resourceGroupName  = string
    }
  )
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
  count               = module.global.keyVault.name != "" ? 1 : 0
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "admin_username" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.adminUsername
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_key_vault_secret" "admin_password" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.adminPassword
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_log_analytics_workspace" "monitor" {
  count               = module.global.monitor.name != "" ? 1 : 0
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

data "terraform_remote_state" "image" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "2.Image.Builder"
  }
}

data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "3.Storage"
  }
}

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "farm" {
  name                 = !local.stateExistsNetwork ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.farm].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_private_dns_zone" "studio" {
  name                = data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azurerm_storage_account" "scheduler" {
  name                = !local.stateExistsStorage ? var.storageAccount.name : data.terraform_remote_state.storage.outputs.blobStorageAccounts[0].name
  resource_group_name = !local.stateExistsStorage ? var.storageAccount.resourceGroupName : data.terraform_remote_state.storage.outputs.resourceGroupName
}

locals {
  stateExistsNetwork = var.computeNetwork.name != "" ? false : try(length(data.terraform_remote_state.network.outputs) > 0, false)
  stateExistsStorage = var.storageAccount.name != "" ? false : try(length(data.terraform_remote_state.storage.outputs) > 0, false)
}

resource "azurerm_resource_group" "farm" {
  name     = var.resourceGroupName
  location = module.global.regionNames[0]
}

output "resourceGroupName" {
  value = azurerm_resource_group.farm.name
}
