#####################################################################################################################################
# The following built-in Azure RBAC role is required for the current user to create Azure Key Vault secrets, certificates and keys. #
# Key Vault Administrator (https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator)       #
#####################################################################################################################################

# Storage (https://docs.microsoft.com/azure/storage)
storage = {
  accountType        = "StorageV2" // https://docs.microsoft.com/azure/storage/common/storage-account-overview
  accountRedundancy  = "LRS"       // https://docs.microsoft.com/azure/storage/common/storage-redundancy
  accountPerformance = "Standard"  // https://docs.microsoft.com/azure/storage/blobs/storage-blob-performance-tiers
}

# Key Vault (https://docs.microsoft.com/azure/key-vault/general/overview)
keyVault = {
  type                    = "standard"
  enablePurgeProtection   = false
  softDeleteRetentionDays = 90
  secrets = [
    {
      name  = "GatewayConnection"
      value = "ConnectionKey"
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
      operations = [
        "decrypt",
        "encrypt",
        "sign",
        "unwrapKey",
        "verify",
        "wrapKey"
      ]
    }
  ]
  certificates = [
  ]
}

# Monitor (https://docs.microsoft.com/azure/azure-monitor/overview)
monitorWorkspace = {
  name               = "AzRender"
  sku                = "PerGB2018"
  retentionDays      = 90
  publicIngestEnable = false
  publicQueryEnable  = false
}
