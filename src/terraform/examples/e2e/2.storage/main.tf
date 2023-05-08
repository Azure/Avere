terraform {
  required_version = ">= 1.4.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.54.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~>0.9.1"
    }
  }
  backend "azurerm" {
    key = "2.storage"
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
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

module "global" {
  source = "../0.global/module"
}

variable "resourceGroupName" {
  type = string
}

variable "dataLoadSource" {
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
  count               = module.global.monitorWorkspace.name != "" ? 1 : 0
  name                = module.global.monitorWorkspace.name
  resource_group_name = module.global.resourceGroupName
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "1.network"
  }
}

data "terraform_remote_state" "image" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "4.image.builder"
  }
}

data "azurerm_resource_group" "network" {
  name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.storageNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.storageNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_virtual_network" "storage" {
  count               = (!local.stateExistsNetwork && var.storageNetwork.name != "") || (local.stateExistsNetwork && data.terraform_remote_state.network.outputs.storageNetwork.name != "") ? 1 : 0
  name                = !local.stateExistsNetwork ? var.storageNetwork.name : data.terraform_remote_state.network.outputs.storageNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.storageNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "compute_storage" {
  name                 = !local.stateExistsNetwork ? var.storageNetwork.subnetNamePrimary : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.storage].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_subnet" "storage_primary" {
  count                = (!local.stateExistsNetwork && var.storageNetwork.name != "") || (local.stateExistsNetwork && data.terraform_remote_state.network.outputs.storageNetwork.name != "") ? 1 : 0
  name                 = !local.stateExistsNetwork ? var.storageNetwork.subnetNamePrimary : data.terraform_remote_state.network.outputs.storageNetwork.subnets[data.terraform_remote_state.network.outputs.storageNetwork.subnetIndex.primary].name
  resource_group_name  = data.azurerm_virtual_network.storage[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage[0].name
}

# data "azurerm_subnet" "storage_secondary" {
#   count                = (!local.stateExistsNetwork && var.storageNetwork.name != "") || (local.stateExistsNetwork && data.terraform_remote_state.network.outputs.storageNetwork.name != "") ? 1 : 0
#   name                 = !local.stateExistsNetwork ? var.storageNetwork.subnetNameSecondary : data.terraform_remote_state.network.outputs.storageNetwork.subnets[data.terraform_remote_state.network.outputs.storageNetwork.subnetIndex.secondary].name
#   resource_group_name  = data.azurerm_virtual_network.storage[0].resource_group_name
#   virtual_network_name = data.azurerm_virtual_network.storage[0].name
# }

data "azurerm_private_dns_zone" "network" {
  name                = !local.stateExistsNetwork ? var.storageNetwork.privateDnsZoneName : data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

locals {
  stateExistsNetwork      = var.storageNetwork.name != "" ? false : try(length(data.terraform_remote_state.network.outputs) > 0, false)
  virtualNetworkSubnet    = try(data.azurerm_subnet.storage_primary[0], data.azurerm_subnet.compute_storage)
  localBinDirectoryPath   = "/usr/local/bin"
  privateDnsRecordSetName = "data"
}

resource "azurerm_resource_group" "storage" {
  name     = var.resourceGroupName
  location = try(data.azurerm_virtual_network.storage[0].location, data.azurerm_virtual_network.compute.location)
}

output "resourceGroupName" {
  value = azurerm_resource_group.storage.name
}
