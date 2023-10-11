##############################################################################
# HPC Cache (https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) #
##############################################################################

variable "hpcCache" {
  type = object({
    throughput = string
    size       = number
    mtuSize    = number
    ntpHost    = string
    dns = object({
      ipAddresses  = list(string)
      searchDomain = string
    })
    encryption = object({
      enable    = bool
      rotateKey = bool
    })
  })
}

data "azuread_service_principal" "hpc_cache" {
  count        = var.enableHPCCache ? 1 : 0
  display_name = "HPC Cache Resource Provider"
}

resource "azurerm_role_assignment" "storage_account" {
  for_each = {
    for storageTargetNfsBlob in var.storageTargetsNfsBlob : storageTargetNfsBlob.name => storageTargetNfsBlob if var.enableHPCCache && storageTargetNfsBlob.enable
  }
  role_definition_name = "Storage Account Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor
  principal_id         = data.azuread_service_principal.hpc_cache[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
}

resource "azurerm_role_assignment" "storage_blob_data" {
  for_each = {
    for storageTargetNfsBlob in var.storageTargetsNfsBlob : storageTargetNfsBlob.name => storageTargetNfsBlob if var.enableHPCCache && storageTargetNfsBlob.enable
  }
  role_definition_name = "Storage Blob Data Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  principal_id         = data.azuread_service_principal.hpc_cache[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
}

resource "azurerm_hpc_cache" "cache" {
  count               = var.enableHPCCache ? 1 : 0
  name                = var.cacheName
  resource_group_name = azurerm_resource_group.cache.name
  location            = azurerm_resource_group.cache.location
  subnet_id           = data.azurerm_subnet.cache.id
  sku_name            = var.hpcCache.throughput
  cache_size_in_gb    = var.hpcCache.size
  mtu                 = var.hpcCache.mtuSize
  ntp_server          = var.hpcCache.ntpHost != "" ? var.hpcCache.ntpHost : null
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  dynamic dns {
    for_each = length(var.hpcCache.dns.ipAddresses) > 0 || var.hpcCache.dns.searchDomain != "" ? [1] : []
    content {
      servers       = var.hpcCache.dns.ipAddresses
      search_domain = var.hpcCache.dns.searchDomain != "" ? var.hpcCache.dns.searchDomain : null
    }
  }
  key_vault_key_id                           = var.hpcCache.encryption.enable ? data.azurerm_key_vault_key.cache_encryption[0].id : null
  automatically_rotate_key_to_latest_enabled = var.hpcCache.encryption.enable ? var.hpcCache.encryption.rotateKey : null
  depends_on = [
    azurerm_role_assignment.storage_account,
    azurerm_role_assignment.storage_blob_data
  ]
}

resource "time_sleep" "blob_nfs_target_rbac" {
  create_duration = "30s"
  depends_on = [
    azurerm_role_assignment.storage_account,
    azurerm_role_assignment.storage_blob_data
  ]
}

resource "azurerm_hpc_cache_nfs_target" "storage" {
  for_each = {
    for storageTargetNfs in var.storageTargetsNfs : storageTargetNfs.name => storageTargetNfs if var.enableHPCCache && storageTargetNfs.enable
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.cache.name
  cache_name          = azurerm_hpc_cache.cache[0].name
  target_host_name    = each.value.storageHost
  usage_model         = each.value.hpcCache.usageModel
  dynamic namespace_junction {
    for_each = each.value.namespaceJunctions
    content {
      nfs_export     = namespace_junction.value["storageExport"]
      target_path    = namespace_junction.value["storagePath"]
      namespace_path = namespace_junction.value["clientPath"]
    }
  }
}

resource "azurerm_hpc_cache_blob_nfs_target" "storage" {
  for_each = {
    for storageTargetNfsBlob in var.storageTargetsNfsBlob : storageTargetNfsBlob.name => storageTargetNfsBlob if var.enableHPCCache && storageTargetNfsBlob.enable
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.cache.name
  cache_name           = azurerm_hpc_cache.cache[0].name
  storage_container_id = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}/blobServices/default/containers/${each.value.storage.containerName}"
  usage_model          = each.value.usageModel
  namespace_path       = each.value.clientPath
  depends_on = [
    time_sleep.blob_nfs_target_rbac
  ]
}
