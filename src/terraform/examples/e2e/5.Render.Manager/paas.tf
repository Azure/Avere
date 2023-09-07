############################################################################
# Batch (https://learn.microsoft.com/azure/batch/batch-technical-overview) #
############################################################################

variable "batch" {
  type = object(
    {
      accountName = string
      networkAccess = object(
        {
          enablePublic = bool
        }
      )
    }
  )
}

data "azurerm_client_config" "studio" {}

data "azuread_service_principal" "batch" {
  count        = var.batch.accountName != "" ? 1 : 0
  display_name = "Microsoft Azure Batch"
}

resource "azurerm_role_assignment" "batch" {
  count                = var.batch.accountName != "" ? 1 : 0
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azuread_service_principal.batch[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}"
}

resource "azurerm_batch_account" "render" {
  count                         = var.batch.accountName != "" ? 1 : 0
  name                          = var.batch.accountName
  resource_group_name           = azurerm_resource_group.scheduler.name
  location                      = azurerm_resource_group.scheduler.location
  public_network_access_enabled = var.batch.networkAccess.enablePublic
  pool_allocation_mode          = "UserSubscription"
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  key_vault_reference {
    id  = data.azurerm_key_vault.studio[0].id
    url = data.azurerm_key_vault.studio[0].vault_uri
  }
  # storage_account_id                  = azurerm_storage_account.example.id
  # storage_account_authentication_mode = "StorageKeys"
  depends_on = [
    azurerm_role_assignment.batch
  ]
}
