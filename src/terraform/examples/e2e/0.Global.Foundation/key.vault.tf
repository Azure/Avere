############################################################################
# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview) #
############################################################################

variable "keyVault" {
  type = object({
    type                        = string
    enableForDeployment         = bool
    enableForDiskEncryption     = bool
    enableForTemplateDeployment = bool
    enablePurgeProtection       = bool
    enableTrustedServices       = bool
    softDeleteRetentionDays     = number
    secrets = list(object({
      name  = string
      value = string
    }))
    keys = list(object({
      name       = string
      type       = string
      size       = number
      operations = list(string)
    }))
    certificates = list(object({
      name        = string
      subject     = string
      issuerName  = string
      contentType = string
      validMonths = number
      key = object({
        type       = string
        size       = number
        reusable   = bool
        exportable = bool
        usage      = list(string)
      })
    }))
  })
}

data "azuread_service_principal" "batch" {
  display_name = "Microsoft Azure Batch"
}

resource "azurerm_key_vault" "studio" {
  count                           = module.global.keyVault.enable ? 1 : 0
  name                            = module.global.keyVault.name
  resource_group_name             = azurerm_resource_group.studio.name
  location                        = azurerm_resource_group.studio.location
  tenant_id                       = data.azurerm_client_config.studio.tenant_id
  sku_name                        = var.keyVault.type
  enabled_for_deployment          = var.keyVault.enableForDeployment
  enabled_for_disk_encryption     = var.keyVault.enableForDiskEncryption
  enabled_for_template_deployment = var.keyVault.enableForTemplateDeployment
  purge_protection_enabled        = var.keyVault.enablePurgeProtection
  soft_delete_retention_days      = var.keyVault.softDeleteRetentionDays
  enable_rbac_authorization       = true
  network_acls {
    bypass         = var.keyVault.enableTrustedServices ? "AzureServices" : "None"
    default_action = "Deny"
    ip_rules = [
      jsondecode(data.http.client_address.response_body).ip
    ]
  }
}

resource "azurerm_key_vault_secret" "studio" {
  for_each = {
    for secret in var.keyVault.secrets : secret.name => secret if module.global.keyVault.enable
  }
  name         = each.value.name
  value        = each.value.value
  key_vault_id = azurerm_key_vault.studio[0].id
}

resource "azurerm_key_vault_key" "studio" {
  for_each = {
    for key in var.keyVault.keys : key.name => key if module.global.keyVault.enable
  }
  name         = each.value.name
  key_type     = each.value.type
  key_size     = each.value.size
  key_opts     = each.value.operations
  key_vault_id = azurerm_key_vault.studio[0].id
}

resource "azurerm_key_vault_certificate" "studio" {
  for_each = {
    for certificate in var.keyVault.certificates : certificate.name => certificate if module.global.keyVault.enable
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

resource "azurerm_key_vault" "batch" {
  count                           = module.global.keyVault.enable ? 1 : 0
  name                            = "${module.global.keyVault.name}-batch"
  resource_group_name             = azurerm_resource_group.studio.name
  location                        = azurerm_resource_group.studio.location
  tenant_id                       = data.azurerm_client_config.studio.tenant_id
  sku_name                        = var.keyVault.type
  enabled_for_deployment          = var.keyVault.enableForDeployment
  enabled_for_disk_encryption     = var.keyVault.enableForDiskEncryption
  enabled_for_template_deployment = var.keyVault.enableForTemplateDeployment
  purge_protection_enabled        = var.keyVault.enablePurgeProtection
  soft_delete_retention_days      = var.keyVault.softDeleteRetentionDays
  enable_rbac_authorization       = false
  network_acls {
    bypass         = var.keyVault.enableTrustedServices ? "AzureServices" : "None"
    default_action = "Deny"
    ip_rules = [
      jsondecode(data.http.client_address.response_body).ip
    ]
  }
}

resource "azurerm_key_vault_access_policy" "batch" {
  count        = module.global.keyVault.enable ? 1 : 0
  key_vault_id = azurerm_key_vault.batch[0].id
  tenant_id    = data.azurerm_client_config.studio.tenant_id
  object_id    = data.azuread_service_principal.batch.object_id
  secret_permissions = [
    "Get",
    "Set",
    "List",
    "Delete",
    "Recover"
  ]
}

output "keyVault" {
  value = {
    enable = module.global.keyVault.enable
    uri    = module.global.keyVault.enable ? azurerm_key_vault.studio[0].vault_uri : null
  }
}
