#######################################################
# Storage (https://learn.microsoft.com/azure/storage) #
#######################################################

rootStorage = {
  accountType        = "StorageV2" # https://learn.microsoft.com/azure/storage/common/storage-account-overview
  accountRedundancy  = "LRS"       # https://learn.microsoft.com/azure/storage/common/storage-redundancy
  accountPerformance = "Standard"  # https://learn.microsoft.com/azure/storage/blobs/storage-blob-performance-tiers
}

############################################################################
# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview) #
############################################################################

keyVault = {
  type                        = "standard"
  enableForDeployment         = true
  enableForDiskEncryption     = true
  enableForTemplateDeployment = true
  enablePurgeProtection       = false
  enableTrustedServices       = true
  softDeleteRetentionDays     = 90
  secrets = [
    {
      name  = "GatewayConnection"
      value = "ConnectionKey"
    },
    {
      name  = "AdminUsername"
      value = "azadmin"
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

######################################################################
# Monitor (https://learn.microsoft.com/azure/azure-monitor/overview) #
######################################################################

monitor = {
  workspace = {
    sku = "PerGB2018"
  }
  insight = {
    type = "Node.JS"
  }
  retentionDays = 90
}
