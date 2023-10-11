#######################################################
# Storage (https://learn.microsoft.com/azure/storage) #
#######################################################

variable "rootStorage" {
  type = object({
    accountType        = string
    accountRedundancy  = string
    accountPerformance = string
  })
}

resource "azurerm_storage_account" "studio" {
  name                            = module.global.rootStorage.accountName
  resource_group_name             = azurerm_resource_group.studio.name
  location                        = azurerm_resource_group.studio.location
  account_kind                    = var.rootStorage.accountType
  account_replication_type        = var.rootStorage.accountRedundancy
  account_tier                    = var.rootStorage.accountPerformance
  allow_nested_items_to_be_public = false
  network_rules {
    default_action = "Deny"
    ip_rules = [
      jsondecode(data.http.client_address.response_body).ip
    ]
  }
}

resource "time_sleep" "storage_account_firewall" {
  create_duration = "30s"
  depends_on = [
    azurerm_storage_account.studio
  ]
}

resource "azurerm_storage_container" "terraform" {
  name                 = module.global.rootStorage.containerName.terraform
  storage_account_name = azurerm_storage_account.studio.name
  depends_on = [
    time_sleep.storage_account_firewall
  ]
}

output "rootStorage" {
  value = {
    accountName  = azurerm_storage_account.studio.name
    blobEndpoint = azurerm_storage_account.studio.primary_blob_endpoint
  }
}
