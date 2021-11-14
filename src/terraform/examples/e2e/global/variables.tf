###############################################################################################################
# IMPORTANT: Make sure the following variable default values match the config values in the 0.Security module #
###############################################################################################################

variable "regionName" {
  type    = string
  default = "WestUS2" // Set to the target Azure region name (az account list-locations --query [].name)
}

variable "securityResourceGroupName" {
  type    = string
  default = "AzureRender"
}

# Terraform backend state configuration
variable "terraformStorageAccountName" {
  type    = string
  default = "azrender"
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
