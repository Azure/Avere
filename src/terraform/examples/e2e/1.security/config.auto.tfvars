###################################################################################################################################################
# The following built-in Azure roles are required for the current user to create KeyVault secrets and keys, respectively                          #
#      Key Vault Secrets Officer (https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-officer)      #
# Key Vault Certificates Officer (https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-certificates-officer) #
#       Key Vault Crypto Officer (https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-crypto-officer)       #
###################################################################################################################################################

# Storage (https://docs.microsoft.com/en-us/azure/storage)
storage = {
  accountType        = "StorageV2" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
  accountRedundancy  = "LRS"       // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
  accountPerformance = "Standard"  // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
}

# Key Vault (https://docs.microsoft.com/en-us/azure/key-vault/general/overview)
keyVault = {
  type = "standard"
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
  certificates = [
    {
      name        = "DeadlineClient"
      subject     = "CN=deadline-client"
      issuerName  = "Self"
      contentType = "application/x-pkcs12"
      validMonths = 12
      key = {
        type       = "RSA"
        size       = 2048
        reusable   = true
        exportable = true
        usage = [
          "keyCertSign"
        ]
      }
    },
    {
      name        = "DeadlineServer"
      subject     = "CN=deadline-server"
      issuerName  = "Self"
      contentType = "application/x-pkcs12"
      validMonths = 12
      key = {
        type       = "RSA"
        size       = 2048
        reusable   = true
        exportable = true
        usage = [
          "keyCertSign"
        ]
      }
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
}

# Monitor (https://docs.microsoft.com/en-us/azure/azure-monitor/overview)
monitorWorkspace = {
  name               = "AzRender"
  sku                = "PerGB2018"
  retentionDays      = 90
  publicIngestEnable = false
  publicQueryEnable  = false
}
