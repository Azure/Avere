variable "regionName" {
  default = "WestUS2" // Set to the target Azure region name (az account list-locations --query [].name)
}

variable "securityResourceGroupName" {
  default = "AzureRender" // Alphanumeric, underscores, hyphens, periods and parenthesis are allowed
}
variable "securityStorageAccountName" {
  default = "azrender" // Set to a globally unique name (lowercase alphanumeric)
}
variable "terraformStorageContainerName" {
  default = "terraform"
}

# Managed Identity (https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
variable "managedIdentityName" {
  default = "AzRender" // Alphanumeric, underscores and hyphens are allowed
}

# Key Vault (https://docs.microsoft.com/en-us/azure/key-vault/general/overview)
variable "keyVaultName" {
  default = "AzRender" // Set to a globally unique name (alphanumeric, hyphens)
}

# KeyVault secret names
variable "keyVaultSecretNameGatewayConnection" {
  default = "GatewayConnection"
}
variable "keyVaultSecretNameAdminPassword" {
  default = "AdminPassword"
}

# KeyVault certificate names
variable "keyVaultCertificateNameDeadlineClient" {
  default = "DeadlineClient"
}
variable "keyVaultCertificateNameDeadlineServer" {
  default = "DeadlineServer"
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
output "keyVaultSecretNameAdminPassword" {
  value = var.keyVaultSecretNameAdminPassword
}

output "keyVaultCertificateNameDeadlineClient" {
  value = var.keyVaultCertificateNameDeadlineClient
}
output "keyVaultCertificateNameDeadlineServer" {
  value = var.keyVaultCertificateNameDeadlineServer
}

output "keyVaultKeyNameCacheEncryption" {
  value = var.keyVaultKeyNameCacheEncryption
}

output "monitorWorkspaceName" {
  value = var.monitorWorkspaceName
}
