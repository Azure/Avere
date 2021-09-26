###########################################################################################################################################
# The following built-in Azure roles are required for the current user to create KeyVault secrets and keys, respectively                  #
# "Key Vault Secrets Officer" - https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-officer #
# "Key Vault Crypto Officer"  - https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-crypto-officer  #
###########################################################################################################################################

resourceGroupName = "AzureRender"

# Storage Account - https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
storageAccountName        = "azurerender" // Name must be globally unique, lowercase alphanumeric
storageAccountType        = "StorageV2"
storageAccountTier        = "Standard"
storageAccountReplication = "LRS"
storageContainerName      = "terraform" // Storage container for Terraform .tfstate files

# Managed Identity - https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview
managedIdentityName = "AzureRender"

# Key Vault - https://docs.microsoft.com/en-us/azure/key-vault/general/overview
keyVaultName = "AzureRender" // Name must be globally unique

# KeyVault secrets should be updated via https://portal.azure.com
keyVaultSecretNames  = ["GatewayConnection", "AdminPassword"]
keyVaultSecretValues = ["SharedKey", "P@ssword1234"]

# KeyVault keys should be updated via https://portal.azure.com
keyVaultKeyNames = ["CacheEncryption"]
keyVaultKeyTypes = ["RSA"]
keyVaultKeySizes = [2048]
