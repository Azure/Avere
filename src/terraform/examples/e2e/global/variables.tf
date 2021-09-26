variable "regionName" {
  type    = string
  default = "EastUS" // Set to the target Azure region name (az account list-locations --query [].name)
}

# Terraform backend state configuration
variable "terraformResourceGroupName" {
  type    = string
  default = "AzureRender" // Set to the resource group name from the 0.security module
}
variable "terraformStorageAccountName" {
  type    = string
  default = "azurerender" // Set to the storage account name from the 0.security module
}
variable "terraformStorageContainerName" {
  type    = string
  default = "terraform" // Set to the storage container from the 0.security module
}

# User-Assigned Managed Identity resource id
variable "managedIdentityId" {
  type    = string
  default = "" // Set to "/subscriptions/[subscription_id]/resourceGroups/[resource_group_name]/providers/Microsoft.ManagedIdentity/userAssignedIdentities/[identity_name]" resource id format
}

# KeyVault resource id
variable "keyVaultId" {
  type    = string
  default = "" // Set to "/subscriptions/[subscription_id]/resourceGroups/[resource_group_name]/providers/Microsoft.KeyVault/vaults/[vault_name]" resource id format
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

# KeyVault key names
variable "keyVaultKeyNameCacheEncryption" {
  type    = string
  default = "CacheEncryption"
}

output "regionName" {
  value = var.regionName
}

output "terraformResourceGroupName" {
  value = var.terraformResourceGroupName
}
output "terraformStorageAccountName" {
  value = var.terraformStorageAccountName
}
output "terraformStorageContainerName" {
  value = var.terraformStorageContainerName
}

output "managedIdentityId" {
  value = var.managedIdentityId
}

output "keyVaultId" {
  value = var.keyVaultId
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
