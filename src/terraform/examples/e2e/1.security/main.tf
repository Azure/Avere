terraform {
  required_version = ">= 1.2.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.21.1"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
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
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

module "global" {
  source = "../0.global"
}

variable "storage" {
  type = object(
    {
      accountType        = string
      accountRedundancy  = string
      accountPerformance = string
    }
  )
}

variable "keyVault" {
  type = object(
    {
      type                    = string
      enablePurgeProtection   = bool
      softDeleteRetentionDays = number
      secrets = list(object(
        {
          name  = string
          value = string
        }
      ))
      keys = list(object(
        {
          name       = string
          type       = string
          size       = number
          operations = list(string)
        }
      ))
      certificates = list(object(
        {
          name        = string
          subject     = string
          issuerName  = string
          contentType = string
          validMonths = number
          key = object(
            {
              type       = string
              size       = number
              reusable   = bool
              exportable = bool
              usage      = list(string)
            }
          )
        }
      ))
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
  name     = module.global.securityResourceGroupName
  location = module.global.regionName
}

resource "azurerm_user_assigned_identity" "identity" {
  name                = module.global.managedIdentityName
  resource_group_name = azurerm_resource_group.security.name
  location            = azurerm_resource_group.security.location
}

resource "azurerm_storage_account" "storage" {
  name                            = module.global.securityStorageAccountName
  resource_group_name             = azurerm_resource_group.security.name
  location                        = azurerm_resource_group.security.location
  account_kind                    = var.storage.accountType
  account_replication_type        = var.storage.accountRedundancy
  account_tier                    = var.storage.accountPerformance
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "container" {
  name                 = module.global.terraformStorageContainerName
  storage_account_name = azurerm_storage_account.storage.name
}

resource "azurerm_key_vault" "vault" {
  name                       = module.global.keyVaultName
  resource_group_name        = azurerm_resource_group.security.name
  location                   = azurerm_resource_group.security.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.keyVault.type
  purge_protection_enabled   = var.keyVault.enablePurgeProtection
  soft_delete_retention_days = var.keyVault.softDeleteRetentionDays
  enable_rbac_authorization  = true
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each = {
    for secret in var.keyVault.secrets : secret.name => secret
  }
  name         = each.value.name
  value        = each.value.value
  key_vault_id = azurerm_key_vault.vault.id
}

resource "azurerm_key_vault_key" "keys" {
  for_each = {
    for key in var.keyVault.keys : key.name => key
  }
  name         = each.value.name
  key_type     = each.value.type
  key_size     = each.value.size
  key_opts     = each.value.operations
  key_vault_id = azurerm_key_vault.vault.id
}

resource "azurerm_key_vault_certificate" "certificates" {
  for_each = {
    for certificate in var.keyVault.certificates : certificate.name => certificate
  }
  name         = each.value.name
  key_vault_id = azurerm_key_vault.vault.id
  certificate_policy {
    x509_certificate_properties {
      subject            = each.value.subject
      key_usage          = each.value.key.usage
      validity_in_months = each.value.validMonths
    }
    issuer_parameters {
      name = each.value.issuerName
    }
    secret_properties {
      content_type = each.value.contentType
    }
    key_properties {
      key_type = each.value.key.type
      key_size = each.value.key.size
      reuse_key = each.value.key.reusable
      exportable = each.value.key.exportable
    }
  }
}

resource "azurerm_log_analytics_workspace" "monitor" {
  name                       = var.monitorWorkspace.name
  resource_group_name        = azurerm_resource_group.security.name
  location                   = azurerm_resource_group.security.location
  sku                        = var.monitorWorkspace.sku
  retention_in_days          = var.monitorWorkspace.retentionDays
  internet_ingestion_enabled = var.monitorWorkspace.publicIngestEnable
  internet_query_enabled     = var.monitorWorkspace.publicQueryEnable
}

output "resourceGroupName" {
  value = module.global.securityResourceGroupName
}

output "managedIdentityName" {
  value = module.global.managedIdentityName
}

output "storage" {
  value = merge(
    { name = module.global.securityStorageAccountName },
    var.storage
  )
}

output "keyVault" {
  value = merge(
    { name = module.global.keyVaultName },
    var.keyVault
  )
}

output "monitorWorkspace" {
  value = var.monitorWorkspace
}
