locals {
  location                     = "eastus"
  keyvault_resource_group_name = "keyvault_rg"
  keyvault_name                = "renderkeyvault"
}

terraform {
  required_version = ">= 0.14.0,< 0.16.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.56.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "keyvaultrg" {
  name     = local.keyvault_resource_group_name
  location = local.location
}

resource "azurerm_key_vault" "keyvault" {
  name                       = local.keyvault_name
  location                   = azurerm_resource_group.keyvaultrg.location
  resource_group_name        = azurerm_resource_group.keyvaultrg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 90
  sku_name                   = "standard"
  enable_rbac_authorization  = true
}

output "location" {
  value = local.location
}

output "keyvault_id" {
  value = azurerm_key_vault.keyvault.id
}
