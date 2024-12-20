terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.75.0"
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
  count               = module.global.keyVault.enable ? 1 : 0
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "gateway_connection" {
  count        = module.global.keyVault.enable ? 1 : 0
  name         = module.global.keyVault.secretName.gatewayConnection
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_key_vault" "batch" {
  count               = module.global.keyVault.enable ? 1 : 0
  name                = "${module.global.keyVault.name}-batch"
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_storage_account" "studio" {
  name                = module.global.rootStorage.accountName
  resource_group_name = module.global.resourceGroupName
}

resource "azurerm_resource_group" "network" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_resource_group" "network_regions" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork
  }
  name     = "${var.resourceGroupName}.${each.value.regionName}"
  location = each.value.regionName
}

output "resourceGroupName" {
  value = azurerm_resource_group.network.name
}

output "resourceGroups" {
  value = [
    for resourceGroup in azurerm_resource_group.network_regions : {
      id   = resourceGroup.id
      name = resourceGroup.name
    }
  ]
}
