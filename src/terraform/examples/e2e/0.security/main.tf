terraform {
  required_version = ">= 1.1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.91.0"
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

variable "managedIdentityName" {
  type = string
}

variable "storage" {
  type = object(
    {
      accountType        = string
      accountRedundancy  = string
      accountPerformance = string
      containerName      = string
    }
  )
}

variable "keyVault" {
  type = object(
    {
      name    = string
      secrets = list(
        object(
          {
            name  = string
            value = string
          }
        )
      )
      keys = list(
        object(
          {
            name = string
            type = string
            size = number
          }
        )
      )
    }
  )
}

variable "monitorWorkspace" {
  type = object(
    {
      name               = string
      sku                = string
      retentionDays      = number
      publicIngestEnable = bool
      publicQueryEnable  = bool
    }
  )
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "security" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_user_assigned_identity" "identity" {
  name                = var.managedIdentityName
  resource_group_name = azurerm_resource_group.security.name
  location            = azurerm_resource_group.security.location
}

resource "azurerm_storage_account" "storage" {
  name                     = module.global.securityStorageAccountName
  resource_group_name      = azurerm_resource_group.security.name
  location                 = azurerm_resource_group.security.location
  account_kind             = var.storage.accountType
  account_replication_type = var.storage.accountRedundancy
  account_tier             = var.storage.accountPerformance
}

resource "azurerm_storage_container" "container" {
  name                 = var.storage.containerName
  storage_account_name = azurerm_storage_account.storage.name
}

resource "azurerm_key_vault" "vault" {
  name                      = var.keyVault.name
  resource_group_name       = azurerm_resource_group.security.name
  location                  = azurerm_resource_group.security.location
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
}

resource "azurerm_key_vault_secret" "secrets" {
  count        = length(var.keyVault.secrets)
  name         = var.keyVault.secrets[count.index].name
  value        = var.keyVault.secrets[count.index].value
  key_vault_id = azurerm_key_vault.vault.id
}

resource "azurerm_key_vault_key" "keys" {
  count        = length(var.keyVault.keys)
  name         = var.keyVault.keys[count.index].name
  key_type     = var.keyVault.keys[count.index].type
  key_size     = var.keyVault.keys[count.index].size
  key_vault_id = azurerm_key_vault.vault.id
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey"
  ]
}

resource "azurerm_log_analytics_workspace" "monitor" {
  name                       = var.monitorWorkspace.name
  location                   = azurerm_resource_group.security.location
  resource_group_name        = azurerm_resource_group.security.name
  sku                        = var.monitorWorkspace.sku
  retention_in_days          = var.monitorWorkspace.retentionDays
  internet_ingestion_enabled = var.monitorWorkspace.publicIngestEnable
  internet_query_enabled     = var.monitorWorkspace.publicQueryEnable
}

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "managedIdentityName" {
  value = var.managedIdentityName
}

output "storage" {
  value = var.storage
}

output "keyVault" {
  value = var.keyVault
}

output "monitorWorkspace" {
  value = var.monitorWorkspace
}
