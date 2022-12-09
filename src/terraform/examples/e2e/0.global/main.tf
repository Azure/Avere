terraform {
  required_version = ">= 1.3.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.34.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~>0.9.1"
    }
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
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

module "global" {
  source = "./module"
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
      type                        = string
      enablePurgeProtection       = bool
      enableForDeployment         = bool
      enableForDiskEncryption     = bool
      enableForTemplateDeployment = bool
      softDeleteRetentionDays     = number
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
      name          = string
      sku           = string
      retentionDays = number
    }
  )
}

data "http" "current" {
  url = "https://api.ipify.org?format=json"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "render" {
  name     = module.global.resourceGroupName
  location = module.global.regionName
}

###########################################################################################################################
# User Assigned Identity (https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview) #
###########################################################################################################################

resource "azurerm_user_assigned_identity" "render" {
  name                = module.global.managedIdentityName
  resource_group_name = azurerm_resource_group.render.name
  location            = azurerm_resource_group.render.location
}

############################################################################
# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview) #
############################################################################

resource "azurerm_key_vault" "render" {
  name                            = module.global.keyVaultName
  resource_group_name             = azurerm_resource_group.render.name
  location                        = azurerm_resource_group.render.location
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = var.keyVault.type
  purge_protection_enabled        = var.keyVault.enablePurgeProtection
  soft_delete_retention_days      = var.keyVault.softDeleteRetentionDays
  enabled_for_deployment          = var.keyVault.enableForDeployment
  enabled_for_disk_encryption     = var.keyVault.enableForDiskEncryption
  enabled_for_template_deployment = var.keyVault.enableForTemplateDeployment
  enable_rbac_authorization       = true
  network_acls {
    bypass         = "None"
    default_action = "Deny"
    ip_rules = [
      jsondecode(data.http.current.response_body).ip
    ]
  }
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each = {
    for secret in var.keyVault.secrets : secret.name => secret
  }
  name         = each.value.name
  value        = each.value.value
  key_vault_id = azurerm_key_vault.render.id
}

resource "azurerm_key_vault_key" "keys" {
  for_each = {
    for key in var.keyVault.keys : key.name => key
  }
  name         = each.value.name
  key_type     = each.value.type
  key_size     = each.value.size
  key_opts     = each.value.operations
  key_vault_id = azurerm_key_vault.render.id
}

resource "azurerm_key_vault_certificate" "certificates" {
  for_each = {
    for certificate in var.keyVault.certificates : certificate.name => certificate
  }
  name         = each.value.name
  key_vault_id = azurerm_key_vault.render.id
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

#######################################################
# Storage (https://learn.microsoft.com/azure/storage) #
#######################################################

resource "azurerm_storage_account" "storage" {
  name                     = module.global.storageAccountName
  resource_group_name      = azurerm_resource_group.render.name
  location                 = azurerm_resource_group.render.location
  account_kind             = var.storage.accountType
  account_replication_type = var.storage.accountRedundancy
  account_tier             = var.storage.accountPerformance
  network_rules {
    default_action = "Deny"
    ip_rules = [
      jsondecode(data.http.current.response_body).ip
    ]
  }
}

resource "time_sleep" "storage_data" {
  create_duration = "30s"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_container" "container" {
  name                 = module.global.storageContainerName
  storage_account_name = azurerm_storage_account.storage.name
  depends_on = [
    time_sleep.storage_data
  ]
}

######################################################################
# Monitor (https://learn.microsoft.com/azure/azure-monitor/overview) #
######################################################################

resource "azurerm_log_analytics_workspace" "monitor" {
  name                       = var.monitorWorkspace.name
  resource_group_name        = azurerm_resource_group.render.name
  location                   = azurerm_resource_group.render.location
  sku                        = var.monitorWorkspace.sku
  retention_in_days          = var.monitorWorkspace.retentionDays
  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

output "resourceGroupName" {
  value = module.global.resourceGroupName
}

output "storage" {
  value = merge(var.storage,
    { name = module.global.storageAccountName }
  )
}

output "keyVault" {
  value = merge(var.keyVault,
    { name = module.global.keyVaultName }
  )
}

output "monitorWorkspace" {
  value = var.monitorWorkspace
}
