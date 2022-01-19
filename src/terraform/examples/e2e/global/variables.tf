variable "regionName" {
  type    = string
  default = "WestUS2" // Set to the target Azure region name (az account list-locations --query [].name)
}

variable "securityResourceGroupName" {
  type    = string
  default = "AzureRender"
}
variable "securityStorageAccountName" {
  type    = string
  default = "azrender" // Set to a globally unique and available storage account name (lowercase alphanumeric)
}
variable "terraformStorageContainerName" {
  type    = string
  default = "terraform"
}

# Managed Identity
variable "managedIdentityName" {
  type    = string
  default = "AzRender"
}

# KeyVault
variable "keyVaultName" {
  type    = string
  default = "AzRender"
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
  default = "AzRender"
}

#####################################################
# The following output values should not be changed #
#####################################################

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
output "keyVaultSecretNameUserPassword" {
  value = var.keyVaultSecretNameUserPassword
}

output "keyVaultKeyNameCacheEncryption" {
  value = var.keyVaultKeyNameCacheEncryption
}

output "monitorWorkspaceName" {
  value = var.monitorWorkspaceName
}
