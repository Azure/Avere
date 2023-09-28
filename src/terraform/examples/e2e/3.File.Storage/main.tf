terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.74.0"
    }
  }
  backend "azurerm" {
    key = "3.File.Storage"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    managed_disk {
      expand_without_downtime = true
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
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

variable "fileLoadSource" {
  type = object(
    {
      accountName   = string
      accountKey    = string
      containerName = string
      blobName      = string
    }
  )
}

variable "storageNetwork" {
  type = object(
    {
      enable              = bool
      name                = string
      resourceGroupName   = string
      subnetNamePrimary   = string
      subnetNameSecondary = string
      privateDnsZoneName  = string
      serviceEndpointSubnets = list(object(
        {
          name               = string
          regionName         = string
          virtualNetworkName = string
        }
      ))
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

data "terraform_remote_state" "image" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "2.Image.Builder"
  }
}

data "azurerm_resource_group" "network" {
  name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azurerm_virtual_network" "compute" {
  name                = var.storageNetwork.enable ? var.storageNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = var.storageNetwork.enable ? var.storageNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_virtual_network" "storage" {
  count               = var.storageNetwork.enable|| data.terraform_remote_state.network.outputs.storageNetwork.enable ? 1 : 0
  name                = var.storageNetwork.enable ? var.storageNetwork.name : data.terraform_remote_state.network.outputs.storageNetwork.name
  resource_group_name = var.storageNetwork.enable ? var.storageNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "compute_storage" {
  name                 = var.storageNetwork.enable ? var.storageNetwork.subnetNamePrimary : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.storage].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_subnet" "storage_primary" {
  count                = var.storageNetwork.enable || data.terraform_remote_state.network.outputs.storageNetwork.enable ? 1 : 0
  name                 = var.storageNetwork.enable ? var.storageNetwork.subnetNamePrimary : data.terraform_remote_state.network.outputs.storageNetwork.subnets[data.terraform_remote_state.network.outputs.storageNetwork.subnetIndex.primary].name
  resource_group_name  = data.azurerm_virtual_network.storage[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage[0].name
}

data "azurerm_subnet" "storage_secondary" {
  count                = var.storageNetwork.enable || data.terraform_remote_state.network.outputs.storageNetwork.enable ? 1 : 0
  name                 = var.storageNetwork.enable ? var.storageNetwork.subnetNameSecondary : data.terraform_remote_state.network.outputs.storageNetwork.subnets[data.terraform_remote_state.network.outputs.storageNetwork.subnetIndex.secondary].name
  resource_group_name  = data.azurerm_virtual_network.storage[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage[0].name
}

data "azurerm_private_dns_zone" "network" {
  name                = var.storageNetwork.enable ? var.storageNetwork.privateDnsZoneName : data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

locals {
  storageSubnet = try(data.azurerm_subnet.storage_primary[0], data.azurerm_subnet.compute_storage)
  binDirectory  = "/usr/local/bin"
}

resource "azurerm_resource_group" "storage" {
  name     = var.resourceGroupName
  location = try(data.azurerm_virtual_network.storage[0].location, data.azurerm_virtual_network.compute.location)
}

output "resourceGroupName" {
  value = azurerm_resource_group.storage.name
}
