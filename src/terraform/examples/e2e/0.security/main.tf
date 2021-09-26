terraform {
  required_version = ">= 1.0.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.78.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "global" {
  source = "../global"
}

variable "resourceGroupName" {
  type = string
}

variable "storageAccountName" {
  type = string
}

variable "storageAccountType" {
  type = string
}

variable "storageAccountTier" {
  type = string
}

variable "storageAccountReplication" {
  type = string
}

variable "storageContainerName" {
  type = string
}

variable "managedIdentityName" {
  type = string
}

variable "keyVaultName" {
  type = string
}

variable "keyVaultSecretNames" {
  type = list(string)
}

variable "keyVaultSecretValues" {
  type = list(string)
}

variable "keyVaultKeyNames" {
  type = list(string)
}

variable "keyVaultKeyTypes" {
  type = list(string)
}

variable "keyVaultKeySizes" {
  type = list(string)
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "security" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_storage_account" "storage" {
  name                     = var.storageAccountName
  resource_group_name      = azurerm_resource_group.security.name
  location                 = azurerm_resource_group.security.location
  account_kind             = var.storageAccountType
  account_tier             = var.storageAccountTier
  account_replication_type = var.storageAccountReplication
}

resource "azurerm_storage_container" "container" {
  name                 = var.storageContainerName
  storage_account_name = azurerm_storage_account.storage.name
}

resource "azurerm_user_assigned_identity" "identity" {
  name                = var.managedIdentityName
  resource_group_name = azurerm_resource_group.security.name
  location            = azurerm_resource_group.security.location
}

resource "azurerm_key_vault" "vault" {
  name                      = var.keyVaultName
  resource_group_name       = azurerm_resource_group.security.name
  location                  = azurerm_resource_group.security.location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
}

resource "azurerm_key_vault_secret" "secrets" {
  count        = length(var.keyVaultSecretNames)
  name         = var.keyVaultSecretNames[count.index]
  value        = var.keyVaultSecretValues[count.index]
  key_vault_id = azurerm_key_vault.vault.id
}

resource "azurerm_key_vault_key" "keys" {
  count        = length(var.keyVaultKeyNames)
  name         = var.keyVaultKeyNames[count.index]
  key_type     = var.keyVaultKeyTypes[count.index]
  key_size     = var.keyVaultKeySizes[count.index]
  key_vault_id = azurerm_key_vault.vault.id
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "storageAccountName" {
  value = var.storageAccountName
}

output "storageContainerName" {
  value = var.storageContainerName
}

output "managedIdentityId" {
  value = azurerm_user_assigned_identity.identity.id
}

output "keyVaultId" {
  value = azurerm_key_vault.vault.id
}

output "keyVaultSecretNames" {
  value = var.keyVaultSecretNames
}

output "keyVaultKeyNames" {
  value = var.keyVaultKeyNames
}
