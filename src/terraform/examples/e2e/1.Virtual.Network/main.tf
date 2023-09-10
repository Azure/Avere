terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.72.0"
    }
  }
  backend "azurerm" {
    key = "1.Virtual.Network"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "global" {
  source = "../0.Global.Foundation/module"
}

variable "resourceGroupName" {
  type = string
}

data "azurerm_client_config" "studio" {}

data "azurerm_key_vault" "studio" {
  count               = module.global.keyVault.name != "" ? 1 : 0
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "gateway_connection" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.gatewayConnection
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_storage_account" "studio" {
  name                = module.global.rootStorage.accountName
  resource_group_name = module.global.resourceGroupName
}

resource "azurerm_resource_group" "network" {
  count    = var.virtualNetwork.name != "" ? 1 : length(module.global.regionNames)
  name     = length(module.global.regionNames) > 1 ? "${var.resourceGroupName}.${module.global.regionNames[count.index]}" : var.resourceGroupName
  location = module.global.regionNames[count.index]
}

output "resourceGroupName" {
  value = var.virtualNetwork.name != "" ? "" : azurerm_resource_group.network[0].name
}
