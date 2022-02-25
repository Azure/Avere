###########################################################################################################################################
# The following built-in Azure roles are required for the current user to create KeyVault secrets and keys, respectively                  #
# "Key Vault Secrets Officer" - https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-officer #
# "Key Vault Crypto Officer"  - https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-crypto-officer  #
###########################################################################################################################################

# Storage - https://docs.microsoft.com/en-us/azure/storage/
storage = {
  accountType        = "StorageV2" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
  accountRedundancy  = "LRS"       // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
  accountPerformance = "Standard"  // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
}

# Key Vault - https://docs.microsoft.com/en-us/azure/key-vault/general/overview
keyVault = {
  secrets = [ // Update secret values via https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-portal
    {
      name  = "GatewayConnection"
      value = "ConnectionKey"
    },
    {
      name  = "ServicePassword"
      value = "P@ssword1234"
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
