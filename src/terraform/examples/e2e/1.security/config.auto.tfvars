// ********************************************************************************************************************************************************
// PREREQUISITE: The Azure "Key Vault Administrator" Role-Based Access Control (RBAC) role is required for the current user BEFORE deploying this module. *
//               https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator                                       *
// ********************************************************************************************************************************************************

#######################################################
# Storage (https://learn.microsoft.com/azure/storage) #
#######################################################

storage = {
  accountType        = "StorageV2" # https://learn.microsoft.com/azure/storage/common/storage-account-overview
  accountRedundancy  = "LRS"       # https://learn.microsoft.com/azure/storage/common/storage-redundancy
  accountPerformance = "Standard"  # https://learn.microsoft.com/azure/storage/blobs/storage-blob-performance-tiers
}

############################################################################
# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview) #
############################################################################

keyVault = {
  type                        = "standard"
  enableForDeployment         = false
  enableForDiskEncryption     = false
  enableForTemplateDeployment = false
  enablePurgeProtection       = false
  softDeleteRetentionDays = 90
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
      name = "BatchEncryption"
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
    },
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

monitorWorkspace = {
  name          = "AzRender"
  sku           = "PerGB2018"
  retentionDays = 90
}