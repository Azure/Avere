############################################################################
# Batch (https://learn.microsoft.com/azure/batch/batch-technical-overview) #
############################################################################

variable "batch" {
  type = object(
    {
      account = object(
        {
          name         = string
          enablePublic = bool
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
              enableInterNodeCommunication = bool
              deallocationMode             = string
            }
          )
          spot = object(
            {
              enable = bool
            }
          )
        }
      ))
      keyVault = object(
        {
          name                        = string
          type                        = string
          enableForDeployment         = bool
          enableForDiskEncryption     = bool
          enableForTemplateDeployment = bool
          enablePurgeProtection       = bool
          enableTrustedServices       = bool
          softDeleteRetentionDays     = number
        }
      )
    }
  )
}

data "azuread_service_principal" "batch" {
  count        = var.batch.account.name != "" ? 1 : 0
  display_name = "Microsoft Azure Batch"
}

data "azurerm_private_dns_zone" "key_vault" {
  count               = var.batch.account.name != "" && !var.batch.account.enablePublic ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azurerm_private_dns_zone" "storage_blob" {
  count               = var.batch.account.name != "" && !var.batch.account.enablePublic ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

resource "azurerm_role_assignment" "scheduler" {
  count                = var.batch.account.name != "" ? 1 : 0
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azuread_service_principal.batch[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}"
}

###############################################################################################
# Private Endpoint (https://learn.microsoft.com/azure/private-link/private-endpoint-overview) #
###############################################################################################

resource "azurerm_private_dns_zone" "batch" {
  count               = var.batch.account.name != "" && !var.batch.account.enablePublic ? 1 : 0
  name                = "privatelink.batch.azure.com"
  resource_group_name = azurerm_resource_group.farm.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "batch" {
  count                 = var.batch.account.name != "" && !var.batch.account.enablePublic ? 1 : 0
  name                  = "${var.batch.account.name}.batch"
  resource_group_name   = azurerm_resource_group.farm.name
  private_dns_zone_name = azurerm_private_dns_zone.batch[0].name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
}

resource "azurerm_private_endpoint" "key_vault" {
  count               = var.batch.account.name != "" && !var.batch.account.enablePublic ? 1 : 0
  name                = "${var.batch.account.name}.vault"
  resource_group_name = azurerm_resource_group.farm.name
  location            = azurerm_resource_group.farm.location
  subnet_id           = data.azurerm_subnet.farm.id
  private_service_connection {
    name                           = azurerm_key_vault.scheduler[0].name
    private_connection_resource_id = azurerm_key_vault.scheduler[0].id
    is_manual_connection           = false
    subresource_names = [
      "vault"
    ]
  }
  private_dns_zone_group {
    name = azurerm_key_vault.scheduler[0].name
    private_dns_zone_ids = [
      data.azurerm_private_dns_zone.key_vault[0].id
    ]
  }
}

resource "azurerm_private_endpoint" "batch" {
  count               = var.batch.account.name != "" && !var.batch.account.enablePublic ? 1 : 0
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
# Key Vault (https://learn.microsoft.com/azure/key-vault/general/overview) #
############################################################################

resource "azurerm_key_vault" "scheduler" {
  count                           = var.batch.account.name != "" ? 1 : 0
  name                            = var.batch.keyVault.name != "" ? var.batch.keyVault.name : var.batch.account.name
  resource_group_name             = azurerm_resource_group.farm.name
  location                        = azurerm_resource_group.farm.location
  tenant_id                       = data.azurerm_client_config.studio.tenant_id
  sku_name                        = var.batch.keyVault.type
  enabled_for_deployment          = var.batch.keyVault.enableForDeployment
  enabled_for_disk_encryption     = var.batch.keyVault.enableForDiskEncryption
  enabled_for_template_deployment = var.batch.keyVault.enableForTemplateDeployment
  purge_protection_enabled        = var.batch.keyVault.enablePurgeProtection
  soft_delete_retention_days      = var.batch.keyVault.softDeleteRetentionDays
  enable_rbac_authorization       = false
  network_acls {
    bypass         = var.batch.keyVault.enableTrustedServices ? "AzureServices" : "None"
    default_action = "Deny"
    ip_rules = [
      jsondecode(data.http.client_address.response_body).ip
    ]
  }
}

resource "azurerm_key_vault_access_policy" "scheduler" {
  count        = var.batch.account.name != "" ? 1 : 0
  key_vault_id = azurerm_key_vault.scheduler[0].id
  tenant_id    = data.azurerm_client_config.studio.tenant_id
  object_id    = data.azuread_service_principal.batch[0].object_id
  secret_permissions = [
    "Get",
    "Set",
    "List",
    "Delete",
    "Recover"
  ]
}

############################################################################
# Batch (https://learn.microsoft.com/azure/batch/batch-technical-overview) #
############################################################################

resource "azurerm_batch_account" "scheduler" {
  count                         = var.batch.account.name != "" ? 1 : 0
  name                          = var.batch.account.name
  resource_group_name           = azurerm_resource_group.farm.name
  location                      = azurerm_resource_group.farm.location
  pool_allocation_mode          = "UserSubscription"
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  network_profile {
    account_access {
      default_action = "Allow"
      ip_rule {
        action   = "Allow"
        ip_range = jsondecode(data.http.client_address.response_body).ip
      }
    }
    node_management_access {
      default_action = "Allow"
      ip_rule {
        action   = "Allow"
        ip_range = jsondecode(data.http.client_address.response_body).ip
      }
    }
  }
  key_vault_reference {
    id  = azurerm_key_vault.scheduler[0].id
    url = azurerm_key_vault.scheduler[0].vault_uri
  }
  # storage_account_id                  = data.azurerm_storage_account.scheduler.id
  # storage_account_authentication_mode = "BatchAccountManagedIdentity"
  depends_on = [
    azurerm_role_assignment.scheduler,
    azurerm_key_vault_access_policy.scheduler
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
  inter_node_communication = each.value.node.enableInterNodeCommunication ? "Enabled" : "Disabled"
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
