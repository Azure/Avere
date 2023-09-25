#################################################################################
# Avere vFXT (https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) #
#################################################################################

variable "vfxtCache" {
  type = object(
    {
      cluster = object(
        {
          nodeSize      = number
          nodeCount     = number
          adminUsername = string
          adminPassword = string
          sshPublicKey  = string
          imageId = object(
            {
              controller = string
              node       = string
            }
          )
        }
      )
      support = object(
        {
          companyName      = string
          enableLogUpload  = bool
          enableProactive  = string
          rollingTraceFlag = string
        }
      )
      localTimezone = string
    }
  )
}

# data "azurerm_resource_group" "studio" {
#   name = module.global.resourceGroupName
# }

# data "azurerm_resource_group" "network" {
#   name = data.azurerm_virtual_network.compute.resource_group_name
# }

locals {
  vfxtControllerAddress   = cidrhost(data.azurerm_subnet.cache.address_prefixes[0], 39)
  vfxtVServerFirstAddress = cidrhost(data.azurerm_subnet.cache.address_prefixes[0], 40)
  vfxtVServerAddressCount = 12
}

# resource "azurerm_role_assignment" "managed_identity" {
#   role_definition_name = "Managed Identity Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-operator
#   principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
#   scope                = data.azurerm_resource_group.studio.id
# }

# resource "azurerm_role_assignment" "network_cache_contributor" {
#   role_definition_name = "Avere Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-contributor
#   principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
#   scope                = data.azurerm_resource_group.network.id
# }

# resource "azurerm_role_assignment" "network_cache_operator" {
#   role_definition_name = "Avere Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-operator
#   principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
#   scope                = data.azurerm_resource_group.network.id
# }

# resource "azurerm_role_assignment" "cache_managed_identity" {
#   role_definition_name = "Managed Identity Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-operator
#   principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
#   scope                = azurerm_resource_group.cache.id
# }

# resource "azurerm_role_assignment" "cache_contributor" {
#   role_definition_name = "Avere Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-contributor
#   principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
#   scope                = azurerm_resource_group.cache.id
# }

# resource "azurerm_role_assignment" "cache_operator" {
#   role_definition_name = "Avere Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-operator
#   principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
#   scope                = azurerm_resource_group.cache.id
# }

module "vfxt_controller" {
  count                             = var.enableHPCCache ? 0 : 1
  source                            = "github.com/Azure/Avere/src/terraform/modules/controller3"
  create_resource_group             = false
  resource_group_name               = var.resourceGroupName
  location                          = module.global.regionNames[0]
  admin_username                    = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : var.vfxtCache.cluster.adminUsername
  admin_password                    = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : var.vfxtCache.cluster.adminPassword
  ssh_key_data                      = var.vfxtCache.cluster.sshPublicKey != "" ? var.vfxtCache.cluster.sshPublicKey : null
  # user_assigned_managed_identity_id = data.azurerm_user_assigned_identity.studio.id
  virtual_network_name              = data.azurerm_virtual_network.compute.name
  virtual_network_resource_group    = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_subnet_name       = data.azurerm_subnet.cache.name
  static_ip_address                 = local.vfxtControllerAddress
  image_id                          = var.vfxtCache.cluster.imageId.controller
  depends_on = [
    azurerm_resource_group.cache,
    # azurerm_role_assignment.managed_identity,
    # azurerm_role_assignment.network_cache_contributor,
    # azurerm_role_assignment.network_cache_operator,
    # azurerm_role_assignment.cache_managed_identity,
    # azurerm_role_assignment.cache_contributor,
    # azurerm_role_assignment.cache_operator
  ]
}

resource "avere_vfxt" "cache" {
  count                           = var.enableHPCCache ? 0 : 1
  vfxt_cluster_name               = lower(var.cacheName)
  azure_resource_group            = var.resourceGroupName
  location                        = module.global.regionNames[0]
  node_cache_size                 = var.vfxtCache.cluster.nodeSize
  vfxt_node_count                 = var.vfxtCache.cluster.nodeCount
  azure_network_name              = data.azurerm_virtual_network.compute.name
  azure_network_resource_group    = data.azurerm_virtual_network.compute.resource_group_name
  azure_subnet_name               = data.azurerm_subnet.cache.name
  # user_assigned_managed_identity  = data.azurerm_user_assigned_identity.studio.id
  controller_address              = module.vfxt_controller[count.index].controller_address
  controller_admin_username       = module.vfxt_controller[count.index].controller_username
  controller_admin_password       = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : var.vfxtCache.cluster.adminPassword
  vfxt_admin_password             = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : var.vfxtCache.cluster.adminPassword
  vfxt_ssh_key_data               = var.vfxtCache.cluster.sshPublicKey != "" ? var.vfxtCache.cluster.sshPublicKey : null
  support_uploads_company_name    = var.vfxtCache.support.companyName
  enable_support_uploads          = var.vfxtCache.support.enableLogUpload
  enable_secure_proactive_support = var.vfxtCache.support.enableProactive
  enable_rolling_trace_data       = var.vfxtCache.support.rollingTraceFlag != ""
  rolling_trace_flag              = var.vfxtCache.support.rollingTraceFlag
  vserver_first_ip                = local.vfxtVServerFirstAddress
  vserver_ip_count                = local.vfxtVServerAddressCount
  timezone                        = var.vfxtCache.localTimezone
  image_id                        = var.vfxtCache.cluster.imageId.node
  node_size                       = var.enableDevMode ? "unsupported_test_SKU" : "prod_sku"
  dynamic core_filer {
    for_each = {
      for storageTargetNfs in var.storageTargetsNfs : storageTargetNfs.name => storageTargetNfs if storageTargetNfs.name != ""
    }
    content {
      name                      = core_filer.value["name"]
      fqdn_or_primary_ip        = core_filer.value["storageHost"]
      cache_policy              = core_filer.value["vfxtCache"].cachePolicy
      nfs_connection_multiplier = core_filer.value["vfxtCache"].nfsConnections
      dynamic junction {
        for_each = core_filer.value["namespaceJunctions"]
        content {
          core_filer_export   = junction.value["storageExport"]
          export_subdirectory = junction.value["storagePath"]
          namespace_path      = junction.value["clientPath"]
        }
      }
    }
  }
  depends_on = [
    module.vfxt_controller
  ]
}
