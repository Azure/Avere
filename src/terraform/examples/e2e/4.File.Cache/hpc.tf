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

data "azurerm_storage_container" "blob_nfs" {
  for_each = {
    for storageTargetNfsBlob in local.storageTargetsNfsBlob : storageTargetNfsBlob.key => storageTargetNfsBlob
  }
  name                 = each.value.storage.containerName
  storage_account_name = each.value.storage.accountName
}

locals {
  storageCaches = [
    for virtualNetwork in data.terraform_remote_state.network.outputs.virtualNetworks : merge(var.hpcCache, {
      key               = "${virtualNetwork.regionName}-${var.cacheName}"
      name              = var.cacheName
      regionName        = virtualNetwork.regionName
      resourceGroupName = "${var.resourceGroupName}.${virtualNetwork.regionName}"
      subnetId          = "${virtualNetwork.id}/subnets/${data.terraform_remote_state.network.outputs.virtualNetwork.subnets[data.terraform_remote_state.network.outputs.virtualNetwork.subnetIndex.cache].name}"
    }) if var.enableHPCCache
  ]
  storageTargetsNfs = flatten([
    for storageCache in local.storageCaches : [
      for storageTargetNfs in var.storageTargetsNfs : merge(storageTargetNfs, {
        key               = "${storageCache.key}-${storageTargetNfs.name}"
        cacheName         = var.cacheName
        resourceGroupName = storageCache.resourceGroupName
      }) if storageTargetNfs.enable
    ] if var.enableHPCCache
  ])
  storageTargetsNfsBlob = flatten([
    for storageCache in local.storageCaches : [
      for storageTargetNfsBlob in var.storageTargetsNfsBlob : merge(storageTargetNfsBlob, {
        key               = "${storageCache.key}-${storageTargetNfsBlob.name}"
        cacheName         = var.cacheName
        resourceGroupName = storageCache.resourceGroupName
      }) if storageTargetNfsBlob.enable
    ] if var.enableHPCCache
  ])
}

resource "azurerm_role_assignment" "storage_account_contributor" {
  for_each = {
    for storageTargetNfsBlob in local.storageTargetsNfsBlob : storageTargetNfsBlob.key => storageTargetNfsBlob
  }
  role_definition_name = "Storage Account Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor
  principal_id         = data.azuread_service_principal.hpc_cache[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  for_each = {
    for storageTargetNfsBlob in local.storageTargetsNfsBlob : storageTargetNfsBlob.key => storageTargetNfsBlob
  }
  role_definition_name = "Storage Blob Data Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  principal_id         = data.azuread_service_principal.hpc_cache[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
}

resource "azurerm_hpc_cache" "studio" {
  for_each = {
    for storageCache in local.storageCaches : storageCache.key => storageCache
  }
  name                = each.value.name
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  subnet_id           = each.value.subnetId
  sku_name            = each.value.throughput
  cache_size_in_gb    = each.value.size
  mtu                 = each.value.mtuSize
  ntp_server          = each.value.ntpHost != "" ? each.value.ntpHost : null
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  dynamic dns {
    for_each = length(each.value.dns.ipAddresses) > 0 || each.value.dns.searchDomain != "" ? [1] : []
    content {
      servers       = each.value.dns.ipAddresses
      search_domain = each.value.dns.searchDomain != "" ? each.value.dns.searchDomain : null
    }
  }
  key_vault_key_id                           = each.value.encryption.enable ? data.azurerm_key_vault_key.cache_encryption[0].id : null
  automatically_rotate_key_to_latest_enabled = each.value.encryption.enable ? each.value.encryption.rotateKey : null
  depends_on = [
    azurerm_resource_group.cache_regions,
    azurerm_role_assignment.storage_account_contributor,
    azurerm_role_assignment.storage_blob_data_contributor
  ]
}

resource "azurerm_hpc_cache_nfs_target" "storage" {
  for_each = {
    for storageTargetNfs in local.storageTargetsNfs : storageTargetNfs.key => storageTargetNfs
  }
  name                = each.value.name
  resource_group_name = each.value.resourceGroupName
  cache_name          = each.value.cacheName
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
  depends_on = [
    azurerm_hpc_cache.studio
  ]
}

resource "azurerm_hpc_cache_blob_nfs_target" "storage" {
  for_each = {
    for storageTargetNfsBlob in local.storageTargetsNfsBlob : storageTargetNfsBlob.key => storageTargetNfsBlob
  }
  name                 = each.value.name
  resource_group_name  = each.value.resourceGroupName
  cache_name           = each.value.cacheName
  storage_container_id = data.azurerm_storage_container.blob_nfs[each.value.key].resource_manager_id
  usage_model          = each.value.usageModel
  namespace_path       = each.value.clientPath
  depends_on = [
    azurerm_hpc_cache.studio
  ]
}

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

resource "azurerm_private_dns_a_record" "studio_hpc" {
  for_each = {
    for storageCache in local.storageCaches : storageCache.key => storageCache
  }
  name                = "cache-${lower(each.value.regionName)}"
  resource_group_name = data.azurerm_private_dns_zone.studio.resource_group_name
  zone_name           = data.azurerm_private_dns_zone.studio.name
  records             = azurerm_hpc_cache.studio[each.value.key].mount_addresses
  ttl                 = 300
}

output "hpcCaches" {
  value = !var.enableHPCCache ? null : [
    for cache in azurerm_hpc_cache.studio : {
      id                = cache.id
      name              = cache.name
      resourceGroupName = cache.resource_group_name
      mountAddresses    = cache.mount_addresses
    }
  ]
}

output "hpcCachesDns" {
  value = !var.enableHPCCache ? null : [
    for dnsRecord in azurerm_private_dns_a_record.studio_hpc : {
      id                = dnsRecord.id
      name              = dnsRecord.name
      resourceGroupName = dnsRecord.resource_group_name
      fqdn              = dnsRecord.fqdn
      records           = dnsRecord.records
    }
  ]
}
