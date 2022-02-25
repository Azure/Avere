variable "regionName" {
  type    = string
  default = "WestUS2" // Set to the target Azure region name (az account list-locations --query [].name)
}

variable "securityResourceGroupName" {
  type    = string
  default = "AzureRender" // Alphanumeric, underscores, hyphens, periods and parenthesis are allowed
}
variable "securityStorageAccountName" {
  type    = string
  default = "azrender" // Set to a globally unique name (lowercase alphanumeric)
}
variable "terraformStorageContainerName" {
  type    = string
  default = "terraform"
}

# Managed Identity - https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview
variable "managedIdentityName" {
  type    = string
  default = "AzRender" // Alphanumeric, underscores and hyphens are allowed
}

# Key Vault - https://docs.microsoft.com/en-us/azure/key-vault/general/overview
variable "keyVaultName" {
  type    = string
  default = "AzRender" // Set to a globally unique name (alphanumeric, hyphens)
}

# KeyVault secret names
variable "keyVaultSecretNameGatewayConnection" {
  type    = string
  default = "GatewayConnection"
}
variable "keyVaultSecretNameServicePassword" {
  type    = string
  default = "ServicePassword"
}
variable "keyVaultSecretNameAdminPassword" {
  type    = string
  default = "AdminPassword"
}

# KeyVault key names
variable "keyVaultKeyNameCacheEncryption" {
  type    = string
  default = "CacheEncryption"
}

variable "monitorWorkspaceName" {
  type    = string
  default = "AzRender"
}

output "regionName" {
  value = var.regionName
}

output "securityResourceGroupName" {
  value = var.securityResourceGroupName
}
output "securityStorageAccountName" {
  value = var.securityStorageAccountName
}
output "terraformStorageContainerName" {
  value = var.terraformStorageContainerName
}

output "managedIdentityName" {
  value = var.managedIdentityName
}

output "keyVaultName" {
  value = var.keyVaultName
}

output "keyVaultSecretNameGatewayConnection" {
  value = var.keyVaultSecretNameGatewayConnection
}
output "keyVaultSecretNameServicePassword" {
  value = var.keyVaultSecretNameServicePassword
}
output "keyVaultSecretNameAdminPassword" {
  value = var.keyVaultSecretNameAdminPassword
}

output "keyVaultKeyNameCacheEncryption" {
  value = var.keyVaultKeyNameCacheEncryption
}

output "monitorWorkspaceName" {
  value = var.monitorWorkspaceName
}
