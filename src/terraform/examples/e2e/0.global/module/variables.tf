####################
# Global Variables #
####################

variable "regionName" {
  default = "WestUS2" # Set default Azure region name (az account list-locations --query [].name)
}

variable "renderManager" {
  default = "Deadline" # RoyalRender or Deadline
}

variable "resourceGroupName" {
  default = "ArtistAnywhere" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed
}
variable "storageAccountName" {
  default = "azrender0" # Set to a globally unique name (lowercase alphanumeric)
}
variable "storageContainerName" {
  default = "terraform"
}

# Managed Identity (https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
variable "managedIdentityName" {
  default = "azrender" # Alphanumeric, underscores and hyphens are allowed
}

# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview)
variable "keyVaultName" {
  default = "azrender" # Set to a globally unique name (alphanumeric, hyphens)
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
variable "keyVaultKeyNameComputeEncryption" {
  default = "ComputeEncryption"
}

variable "monitorWorkspaceName" {
  default = "azrender"
}

output "regionName" {
  value = var.regionName
}

output "renderManager" {
  value = var.renderManager
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
output "keyVaultKeyNameComputeEncryption" {
  value = var.keyVaultKeyNameComputeEncryption
}

output "monitorWorkspaceName" {
  value = var.monitorWorkspaceName
}
