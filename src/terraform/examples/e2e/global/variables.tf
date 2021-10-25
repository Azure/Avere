variable "regionName" {
  type    = string
  default = "WestUS2" // Set to the target Azure region name (az account list-locations --query [].name)
}

variable "securityResourceGroupName" {
  type    = string
  default = "AzureRender" // Set to the resource group name from the 0.security module
}

# Terraform backend state configuration
variable "terraformStorageAccountName" {
  type    = string
  default = "azrender" // Set to the storage account name from the 0.security module
}
variable "terraformStorageContainerName" {
  type    = string
  default = "terraform" // Set to the storage container from the 0.security module
}

# Managed Identity
variable "managedIdentityName" {
  type    = string
  default = "AzRender" // Set to the managed identity name from the 0.security module
}

# KeyVault
variable "keyVaultName" {
  type    = string
  default = "AzRender" // Set to the key vault name from the 0.security module
}

# KeyVault secret names
variable "keyVaultSecretNameGatewayConnection" {
  type    = string
  default = "GatewayConnection"
}
variable "keyVaultSecretNameAdminPassword" {
  type    = string
  default = "AdminPassword"
}
variable "keyVaultSecretNameUserPassword" {
  type    = string
  default = "UserPassword"
}

# KeyVault key names
variable "keyVaultKeyNameCacheEncryption" {
  type    = string
  default = "CacheEncryption"
}

variable "monitorWorkspaceName" {
  type    = string
  default = "AzRender" // Set to the monitor workspace name from the 0.security module
}

output "regionName" {
  value = var.regionName
}

output "securityResourceGroupName" {
  value = var.securityResourceGroupName
}

output "terraformStorageAccountName" {
  value = var.terraformStorageAccountName
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
output "keyVaultSecretNameUserPassword" {
  value = var.keyVaultSecretNameUserPassword
}

output "keyVaultKeyNameCacheEncryption" {
  value = var.keyVaultKeyNameCacheEncryption
}

output "monitorWorkspaceName" {
  value = var.monitorWorkspaceName
}
