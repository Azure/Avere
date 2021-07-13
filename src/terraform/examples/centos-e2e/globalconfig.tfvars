# the location of the keyvault and storage account
location = "eastus"

# the keyvaule id (from the output of 0.security)
key_vault_id = ""

# backend, needed for populating data terraform_remote_state
# there is duplication with backend, but is required to populate data
resource_group_name  = "tfsecurity_rg"
storage_account_name = "tfstgaccount"
container_name       = "terraform"

# keyvault key names
vpn_gateway_key    = "vpngatewaykey"
virtualmachine_key = "virtualmachine"
averecache_key     = "AvereCache"
