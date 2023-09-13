############################################################################
# Batch (https://learn.microsoft.com/azure/batch/batch-technical-overview) #
############################################################################

variable "batch" {
  type = object(
    {
      account = object(
        {
          name = string
        }
      )
      pools = list(object(
        {
          name        = string
          displayName = string
          node = object(
            {
              image = object(
                {
                  id      = string
                  agentId = string
                }
              )
              machine = object(
                {
                  size  = string
                  count = number
                }
              )
              deallocationMode = string
            }
          )
          spot = object(
            {
              enable = bool
            }
          )
        }
      ))
    }
  )
}

data "azuread_service_principal" "batch" {
  count        = var.batch.account.name != "" ? 1 : 0
  display_name = "Microsoft Azure Batch"
}

data "azurerm_private_dns_zone" "storage_blob" {
  count               = var.batch.account.name != "" ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azurerm_key_vault" "batch" {
  count               = module.global.keyVault.name != "" ? 1 : 0
  name                = "${module.global.keyVault.name}-batch"
  resource_group_name = module.global.resourceGroupName
}

###############################################################################################
# Private Endpoint (https://learn.microsoft.com/azure/private-link/private-endpoint-overview) #
###############################################################################################

resource "azurerm_private_dns_zone" "batch" {
  count               = var.batch.account.name != "" ? 1 : 0
  name                = "privatelink.batch.azure.com"
  resource_group_name = azurerm_resource_group.farm.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "batch" {
  count                 = var.batch.account.name != "" ? 1 : 0
  name                  = "${var.batch.account.name}.batch"
  resource_group_name   = azurerm_resource_group.farm.name
  private_dns_zone_name = azurerm_private_dns_zone.batch[0].name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
}

resource "azurerm_private_endpoint" "batch" {
  count               = var.batch.account.name != "" ? 1 : 0
  name                = "${var.batch.account.name}.batch"
  resource_group_name = azurerm_resource_group.farm.name
  location            = azurerm_resource_group.farm.location
  subnet_id           = data.azurerm_subnet.farm.id
  private_service_connection {
    name                           = azurerm_batch_account.scheduler[0].name
    private_connection_resource_id = azurerm_batch_account.scheduler[0].id
    is_manual_connection           = false
    subresource_names = [
      "batchAccount"
    ]
  }
  private_dns_zone_group {
    name = azurerm_batch_account.scheduler[0].name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.batch[0].id
    ]
  }
}

############################################################################
# Batch (https://learn.microsoft.com/azure/batch/batch-technical-overview) #
############################################################################

resource "azurerm_role_assignment" "batch" {
  count                = var.batch.account.name != "" ? 1 : 0
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azuread_service_principal.batch[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}"
}

resource "azurerm_batch_account" "scheduler" {
  count                         = var.batch.account.name != "" ? 1 : 0
  name                          = var.batch.account.name
  resource_group_name           = azurerm_resource_group.farm.name
  location                      = azurerm_resource_group.farm.location
  pool_allocation_mode          = "UserSubscription"
  public_network_access_enabled = false
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  network_profile {
    account_access {
      default_action = "Deny"
      ip_rule {
        action   = "Allow"
        ip_range = jsondecode(data.http.client_address.response_body).ip
      }
    }
    node_management_access {
      default_action = "Deny"
      ip_rule {
        action   = "Allow"
        ip_range = jsondecode(data.http.client_address.response_body).ip
      }
    }
  }
  key_vault_reference {
    id  = data.azurerm_key_vault.batch[0].id
    url = data.azurerm_key_vault.batch[0].vault_uri
  }
  # storage_account_id                  = data.azurerm_storage_account.scheduler.id
  # storage_account_authentication_mode = "BatchAccountManagedIdentity"
  depends_on = [
    azurerm_role_assignment.batch
  ]
}

resource "azurerm_batch_pool" "farm" {
  for_each = {
    for pool in var.batch.pools : pool.name => pool if var.batch.account.name != "" && pool.name != ""
  }
  name                     = each.value.name
  display_name             = each.value.displayName != "" ? each.value.displayName : each.value.name
  resource_group_name      = azurerm_resource_group.farm.name
  account_name             = azurerm_batch_account.scheduler[0].name
  vm_size                  = each.value.node.machine.size
  node_agent_sku_id        = each.value.node.image.agentId
  inter_node_communication = "Disabled"
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  storage_image_reference {
    id = each.value.node.image.id
  }
  network_configuration {
    subnet_id = data.azurerm_subnet.farm.id
  }
  fixed_scale {
    target_dedicated_nodes    = each.value.spot.enable ? 0 : each.value.node.machine.count
    target_low_priority_nodes = each.value.spot.enable ? each.value.node.machine.count : 0
    node_deallocation_method  = each.value.node.deallocationMode
  }
}

output "batchAccountEndpoint" {
  value = var.batch.account.name != "" ? azurerm_batch_account.scheduler[0].account_endpoint : ""
}
