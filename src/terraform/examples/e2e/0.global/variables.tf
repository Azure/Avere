####################
# Global Variables #
####################

variable "regionName" {
  default = "SouthCentralUS" # Set to the target Azure region name (az account list-locations --query [].name)
}

variable "securityResourceGroupName" {
  default = "ArtistAnywhere" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed
}
variable "securityStorageAccountName" {
  default = "azrender0" # Set to a globally unique name (lowercase alphanumeric)
}
variable "terraformStorageContainerName" {
  default = "terraform"
}

# Managed Identity (https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
variable "managedIdentityName" {
  default = "AzRender" # Alphanumeric, underscores and hyphens are allowed
}

# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview)
variable "keyVaultName" {
  default = "AzRender" # Set to a globally unique name (alphanumeric, hyphens)
}

# KeyVault secret names
variable "keyVaultSecretNameGatewayConnection" {
  default = "GatewayConnection"
}
variable "keyVaultSecretNameAdminUsername" {
  default = "AdminUsername"
}
variable "keyVaultSecretNameAdminPassword" {
  default = "AdminPassword"
}

# KeyVault key names
variable "keyVaultKeyNameCacheEncryption" {
  default = "CacheEncryption"
}

variable "monitorWorkspaceName" {
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
output "keyVaultSecretNameAdminUsername" {
  value = var.keyVaultSecretNameAdminUsername
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
