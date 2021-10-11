###########################################################################################################################################
# The following built-in Azure roles are required for the current user to create KeyVault secrets and keys, respectively                  #
# "Key Vault Secrets Officer" - https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-officer #
# "Key Vault Crypto Officer"  - https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-crypto-officer  #
###########################################################################################################################################

resourceGroupName = "AzureRender"

# Managed Identity - https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview
managedIdentityName = "AzureRender"

# Storage - https://docs.microsoft.com/en-us/azure/storage/
storage = {
  accountName        = "azurerender" // Name must be globally unique, lowercase alphanumeric
  accountType        = "StorageV2"   // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
  accountRedundancy  = "LRS"         // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
  accountPerformance = "Standard"    // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
  containerName      = "terraform"   // Storage container for Terraform .tfstate files
}

# Key Vault - https://docs.microsoft.com/en-us/azure/key-vault/general/overview
keyVault = {
  name    = "AzureRender" // Name must be globally unique
  secrets = [ // Update secret values via https://portal.azure.com
    {
      name  = "GatewayConnection"
      value = "SharedKey"
    },
    {
      name  = "AdminPassword"
      value = "P@ssword1234"
    }
  ]
  keys = [
    {
      name = "CacheEncryption"
      type = "RSA"
      size = 2048
    }
  ]
}
