############################################################################
# Batch (https://learn.microsoft.com/azure/batch/batch-technical-overview) #
############################################################################

variable "batch" {
  type = object(
    {
      enable = bool
      account = object(
        {
          name = string
          storage = object(
            {
              accountName       = string
              resourceGroupName = string
            }
          )
        }
      )
      pools = list(object(
        {
          enable      = bool
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
              osDisk = object(
                {
                  ephemeral = object(
                    {
                      enable = bool
                    }
                  )
                }
              )
              deallocationMode   = string
              maxConcurrentTasks = number
            }
          )
          spot = object(
            {
              enable = bool
            }
          )
          fillMode = object(
            {
              nodePack = bool
            }
          )
        }
      ))
    }
  )
}

data "azuread_service_principal" "batch" {
  count        = var.batch.enable ? 1 : 0
  display_name = "Microsoft Azure Batch"
}

data "azurerm_key_vault" "batch" {
  count               = module.global.keyVault.enable ? 1 : 0
  name                = "${module.global.keyVault.name}-batch"
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_storage_account" "batch" {
  count               = var.batch.enable ? 1 : 0
  name                = local.storageAccount.name
  resource_group_name = local.storageAccount.resourceGroupName
}

locals {
  storageAccount = try(data.terraform_remote_state.storage.outputs.blobStorageAccounts[0], merge({"name" = var.batch.account.storage.accountName}, {"resourceGroupName" = var.batch.account.storage.resourceGroupName}))
}

###############################################################################################
# Private Endpoint (https://learn.microsoft.com/azure/private-link/private-endpoint-overview) #
###############################################################################################

resource "azurerm_private_dns_zone" "batch" {
  count               = var.batch.enable ? 1 : 0
  name                = "privatelink.batch.azure.com"
  resource_group_name = azurerm_resource_group.farm.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "batch" {
  count                 = var.batch.enable ? 1 : 0
  name                  = "${data.azurerm_virtual_network.compute.name}-batch"
  resource_group_name   = azurerm_resource_group.farm.name
  private_dns_zone_name = azurerm_private_dns_zone.batch[0].name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
}

resource "azurerm_private_endpoint" "batch_account" {
  count               = var.batch.enable ? 1 : 0
  name                = "${var.batch.account.name}-batchAccount"
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

resource "azurerm_private_endpoint" "batch_node" {
  count               = var.batch.enable ? 1 : 0
  name                = "${var.batch.account.name}-batchNode"
  resource_group_name = azurerm_resource_group.farm.name
  location            = azurerm_resource_group.farm.location
  subnet_id           = data.azurerm_subnet.farm.id
  private_service_connection {
    name                           = azurerm_batch_account.scheduler[0].name
    private_connection_resource_id = azurerm_batch_account.scheduler[0].id
    is_manual_connection           = false
    subresource_names = [
      "nodeManagement"
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
  count                = var.batch.enable ? 1 : 0
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azuread_service_principal.batch[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}"
}

resource "azurerm_batch_account" "scheduler" {
  count                = var.batch.enable ? 1 : 0
  name                 = var.batch.account.name
  resource_group_name  = azurerm_resource_group.farm.name
  location             = azurerm_resource_group.farm.location
  pool_allocation_mode = "UserSubscription"
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
  storage_account_id                  = data.azurerm_storage_account.batch[0].id
  storage_account_node_identity       = data.azurerm_user_assigned_identity.studio.id
  storage_account_authentication_mode = "BatchAccountManagedIdentity"
  depends_on = [
    azurerm_role_assignment.batch
  ]
}

resource "azurerm_batch_pool" "farm" {
  for_each = {
    for pool in var.batch.pools : pool.name => pool if var.batch.enable && pool.enable
  }
  name                     = each.value.name
  display_name             = each.value.displayName != "" ? each.value.displayName : each.value.name
  resource_group_name      = azurerm_resource_group.farm.name
  account_name             = azurerm_batch_account.scheduler[0].name
  vm_size                  = each.value.node.machine.size
  node_agent_sku_id        = each.value.node.image.agentId
  max_tasks_per_node       = each.value.node.maxConcurrentTasks
  os_disk_placement        = each.value.node.osDisk.ephemeral.enable ? "CacheDisk" : null
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
  task_scheduling_policy {
    node_fill_type = each.value.fillMode.nodePack ? "Pack" : "Spread"
  }
}

output "batchAccountEndpoint" {
  value = var.batch.enable ? azurerm_batch_account.scheduler[0].account_endpoint : ""
}
