/*
* For security deploy:
* 1. keyvault - to store secrets
* 2. storage account - to store terraform state
*/

#### Versions
terraform {
  required_version = ">= 0.14.0"
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

### Variables
variable "location" {
  type = string
}

variable "tfsecurity_rg" {
  type = string
}

variable "keyvault_name" {
  type = string
}

variable "secret_keys" {
  type = list(string)
}

variable "secret_dummy_value" {
  type = string
}

variable "tfbackend_storage_account_name" {
  type = string
}

variable "tfbackend_storage_container_name" {
  type = string
}

### Resources
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "tfsecurity_rg" {
  name     = var.tfsecurity_rg
  location = var.location
}

resource "azurerm_key_vault" "keyvault" {
  name                       = var.keyvault_name
  location                   = azurerm_resource_group.tfsecurity_rg.location
  resource_group_name        = azurerm_resource_group.tfsecurity_rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 90
  sku_name                   = "standard"
  enable_rbac_authorization  = true
}

resource "azurerm_key_vault_secret" "secretkeys" {
  count        = length(var.secret_keys)
  name         = var.secret_keys[count.index]
  value        = var.secret_dummy_value
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_storage_account" "tfbackend" {
  name                     = var.tfbackend_storage_account_name
  location                 = azurerm_resource_group.tfsecurity_rg.location
  resource_group_name      = azurerm_resource_group.tfsecurity_rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "tfbackend" {
  name                 = var.tfbackend_storage_container_name
  storage_account_name = azurerm_storage_account.tfbackend.name
}

### Outputs
output "location" {
  value = var.location
}

output "key_vault_id" {
  value = azurerm_key_vault.keyvault.id
}

output "resource_group_name" {
  value = azurerm_resource_group.tfsecurity_rg.name
}

output "storage_account_name" {
  value = azurerm_storage_account.tfbackend.name
}

output "container_name" {
  value = azurerm_storage_container.tfbackend.name
}
