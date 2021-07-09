// customize the simple VM by editing the following local variables
locals {
  // storage details
  storage_resource_group_name = "houdini_storage_rg"
  storage_account_name        = "houdinistgacct"

  // replace below variables with the infrastructure variables from 1.base_infrastructure
  location                       = ""
  vnet_cloud_cache_subnet_id     = ""
  vnet_cloud_cache_subnet_name   = ""
  vnet_jumpbox_subnet_id         = ""
  vnet_jumpbox_subnet_name       = ""
  vnet_name                      = ""
  vnet_render_clients1_subnet_id = ""
  vnet_resource_group            = ""
}

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "storage" {
  name     = local.storage_resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  network_rules {
    virtual_network_subnet_ids = [
      local.vnet_cloud_cache_subnet_id,
      // need for the controller to create the container
      local.vnet_jumpbox_subnet_id,
    ]
    default_action = "Deny"
  }
}

output "storage_resource_group_name" {
  value = local.storage_resource_group_name
}

output "storage_account_name" {
  value = local.storage_account_name
}

output "use_blob_storage" {
  value = true
}
