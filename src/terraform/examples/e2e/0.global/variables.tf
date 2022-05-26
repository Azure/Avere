variable "regionName" {
  default = "WestUS2" // Set to the target Azure region name (az account list-locations --query [].name)
}

variable "securityResourceGroupName" {
  default = "ArtistAnywhere" // Alphanumeric, underscores, hyphens, periods and parenthesis are allowed
}
variable "securityStorageAccountName" {
  default = "azartist0" // Set to a globally unique name (lowercase alphanumeric)
}
variable "terraformStorageContainerName" {
  default = "terraform"
}

# Managed Identity (https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
variable "managedIdentityName" {
  default = "AzArtist" // Alphanumeric, underscores and hyphens are allowed
}

# Key Vault (https://docs.microsoft.com/azure/key-vault/general/overview)
variable "keyVaultName" {
  default = "AzArtist" // Set to a globally unique name (alphanumeric, hyphens)
}

# KeyVault secret names
variable "keyVaultSecretNameGatewayConnection" {
  default = "GatewayConnection"
}
variable "keyVaultSecretNameAdminPassword" {
  default = "AdminPassword"
}

# KeyVault key names
variable "keyVaultKeyNameCacheEncryption" {
  default = "CacheEncryption"
}

variable "monitorWorkspaceName" {
  default = "AzArtist"
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
output "keyVaultSecretNameAdminPassword" {
  value = var.keyVaultSecretNameAdminPassword
}

output "keyVaultKeyNameCacheEncryption" {
  value = var.keyVaultKeyNameCacheEncryption
}

output "monitorWorkspaceName" {
  value = var.monitorWorkspaceName
}
