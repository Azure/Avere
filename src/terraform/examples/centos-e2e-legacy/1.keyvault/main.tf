locals {
  location                     = "eastus"
  keyvault_resource_group_name = "keyvault_rg"
  keyvault_name                = "renderkeyvault"
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

resource "azurerm_key_vault_secret" "vpngatewaykey" {
  name         = "vpngatewaykey"
  value        = "replace with correct value"
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "virtualmachine" {
  name         = "virtualmachine"
  value        = "replace with correct value"
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "AvereCache" {
  name         = "AvereCache"
  value        = "replace with correct value"
  key_vault_id = azurerm_key_vault.keyvault.id
}

output "location" {
  value = local.location
}

output "key_vault_id" {
  value = azurerm_key_vault.keyvault.id
}
