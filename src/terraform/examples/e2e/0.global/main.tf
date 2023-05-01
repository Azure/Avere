terraform {
  required_version = ">= 1.4.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.54.0"
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

variable "rootStorage" {
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
      sku           = string
      retentionDays = number
    }
  )
}

data "http" "client_address" {
  url = "https://api.ipify.org?format=json"
}

data "azurerm_client_config" "provider" {}

resource "azurerm_resource_group" "studio" {
  name     = module.global.resourceGroupName
  location = module.global.regionName
}

#######################################################
# Storage (https://learn.microsoft.com/azure/storage) #
#######################################################

resource "azurerm_storage_account" "storage" {
  name                            = module.global.rootStorage.accountName
  resource_group_name             = azurerm_resource_group.studio.name
  location                        = azurerm_resource_group.studio.location
  account_kind                    = var.rootStorage.accountType
  account_replication_type        = var.rootStorage.accountRedundancy
  account_tier                    = var.rootStorage.accountPerformance
  allow_nested_items_to_be_public = false
  network_rules {
    default_action = "Deny"
    ip_rules = [
      jsondecode(data.http.client_address.response_body).ip
    ]
  }
}

resource "time_sleep" "storage" {
  create_duration = "30s"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_container" "terraform" {
  name                 = module.global.rootStorage.containerName.terraform
  storage_account_name = azurerm_storage_account.storage.name
  depends_on = [
    time_sleep.storage
  ]
}

#####################################################################################################################
# Managed Identity (https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview) #
#####################################################################################################################

resource "azurerm_user_assigned_identity" "studio" {
  name                = module.global.managedIdentity.name
  resource_group_name = azurerm_resource_group.studio.name
  location            = azurerm_resource_group.studio.location
}

############################################################################
# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview) #
############################################################################

resource "azurerm_key_vault" "studio" {
  count                           = module.global.keyVault.name != "" ? 1 : 0
  name                            = module.global.keyVault.name
  resource_group_name             = azurerm_resource_group.studio.name
  location                        = azurerm_resource_group.studio.location
  tenant_id                       = data.azurerm_client_config.provider.tenant_id
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
      jsondecode(data.http.client_address.response_body).ip
    ]
  }
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each = {
    for secret in var.keyVault.secrets : secret.name => secret if module.global.keyVault.name != ""
  }
  name         = each.value.name
  value        = each.value.value
  key_vault_id = azurerm_key_vault.studio[0].id
}

resource "azurerm_key_vault_key" "keys" {
  for_each = {
    for key in var.keyVault.keys : key.name => key if module.global.keyVault.name != ""
  }
  name         = each.value.name
  key_type     = each.value.type
  key_size     = each.value.size
  key_opts     = each.value.operations
  key_vault_id = azurerm_key_vault.studio[0].id
}

resource "azurerm_key_vault_certificate" "certificates" {
  for_each = {
    for certificate in var.keyVault.certificates : certificate.name => certificate if module.global.keyVault.name != ""
  }
  name         = each.value.name
  key_vault_id = azurerm_key_vault.studio[0].id
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

######################################################################
# Monitor (https://learn.microsoft.com/azure/azure-monitor/overview) #
######################################################################

resource "azurerm_log_analytics_workspace" "monitor" {
  count                      = module.global.monitorWorkspace.name != "" ? 1 : 0
  name                       = module.global.monitorWorkspace.name
  resource_group_name        = azurerm_resource_group.studio.name
  location                   = azurerm_resource_group.studio.location
  sku                        = var.monitorWorkspace.sku
  retention_in_days          = var.monitorWorkspace.retentionDays
  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

output "resourceGroupName" {
  value = module.global.resourceGroupName
}
