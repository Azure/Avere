# the location of the keyvault and storage account
location = "eastus"

# resource group to hold keyvault and terraform storage account
tfsecurity_rg = "tfsecurity_rg"

# name of the keyvault
keyvault_name = "renderkeyvault"

# name of terraform storage account (alphanumeric, globabally unique)
tfbackend_storage_account_name = "tfstgaccount"

# name of the storage container to store the .tfstate files
tfbackend_storage_container_name = "terraform"

################################################################
# Advance Settings
# the names of the keys in the keyvault
secret_keys = ["vpngatewaykey", "virtualmachine", "AvereCache"]

# used as initial place holders for the secrets
secret_dummy_value = "initialplaceholder"
