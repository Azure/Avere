terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.72.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.41.0"
    }
  }
  backend "azurerm" {
    key = "5.Render.Manager"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy                            = true
      purge_soft_deleted_secrets_on_destroy                   = true
      purge_soft_deleted_keys_on_destroy                      = true
      purge_soft_deleted_certificates_on_destroy              = true
      purge_soft_deleted_hardware_security_modules_on_destroy = true
      recover_soft_deleted_key_vaults                         = true
      recover_soft_deleted_secrets                            = true
      recover_soft_deleted_keys                               = true
      recover_soft_deleted_certificates                       = true
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

variable "privateDns" {
  type = object(
    {
      aRecordName = string
      ttlSeconds  = number
    }
  )
}

variable "computeNetwork" {
  type = object(
    {
      name               = string
      subnetName         = string
      resourceGroupName  = string
      privateDnsZoneName = string
    }
  )
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

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "farm" {
  name                 = !local.stateExistsNetwork ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.farm].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_private_dns_zone" "network" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.privateDnsZoneName : data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

locals {
  stateExistsNetwork = var.computeNetwork.name != "" ? false : try(length(data.terraform_remote_state.network.outputs) > 0, false)
}

resource "azurerm_resource_group" "scheduler" {
  name     = var.resourceGroupName
  location = module.global.regionNames[0]
}

resource "azurerm_private_dns_a_record" "scheduler" {
  name                = var.privateDns.aRecordName
  resource_group_name = data.azurerm_private_dns_zone.network.resource_group_name
  zone_name           = data.azurerm_private_dns_zone.network.name
  ttl                 = var.privateDns.ttlSeconds
  records = [
    azurerm_network_interface.scheduler[local.virtualMachineNames[0]].private_ip_address
  ]
}

output "resourceGroupName" {
  value = azurerm_resource_group.scheduler.name
}

output "privateDnsRecord" {
  value = azurerm_private_dns_a_record.scheduler
}
