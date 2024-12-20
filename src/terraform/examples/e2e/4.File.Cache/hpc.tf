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

locals {
  storageCaches = distinct(var.existingNetwork.enable ? [
    for i in range(length(local.virtualNetworks)) : merge(var.hpcCache, {
      name              = "${module.global.regionName}-${var.cacheName}"
      regionName        = module.global.regionName
      resourceGroupName = "${var.resourceGroupName}.${module.global.regionName}"
      subnetId          = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${var.existingNetwork.resourceGroupName}/providers/Microsoft.Network/virtualNetworks/${var.existingNetwork.name}/subnets/${var.existingNetwork.subnetName}"
    }) if var.enableHPCCache
  ] : [
    for virtualNetwork in local.virtualNetworks : merge(var.hpcCache, {
      name              = "${virtualNetwork.regionName}-${var.cacheName}"
      regionName        = virtualNetwork.regionName
      resourceGroupName = "${var.resourceGroupName}.${virtualNetwork.regionName}"
      subnetId          = "${virtualNetwork.id}/subnets/${data.terraform_remote_state.network.outputs.virtualNetwork.subnets[data.terraform_remote_state.network.outputs.virtualNetwork.subnetIndex.cache].name}"
    }) if var.enableHPCCache
  ])
  storageTargetsNfs = flatten([
    for storageCache in local.storageCaches : [
      for storageTargetNfs in var.storageTargetsNfs : merge(storageTargetNfs, {
        cacheName         = storageCache.name
        resourceGroupName = storageCache.resourceGroupName
      }) if storageTargetNfs.enable
    ]
  ])
  storageTargetsNfsBlob = flatten([
    for storageCache in local.storageCaches : [
      for storageTargetNfsBlob in var.storageTargetsNfsBlob : merge(storageTargetNfsBlob, {
        cacheName         = storageCache.name
        resourceGroupName = storageCache.resourceGroupName
      }) if storageTargetNfsBlob.enable
    ]
  ])
}

resource "azurerm_role_assignment" "storage_account_contributor" {
  for_each = {
    for storageTargetNfsBlob in var.storageTargetsNfsBlob: storageTargetNfsBlob.name => storageTargetNfsBlob
  }
  role_definition_name = "Storage Account Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor
  principal_id         = data.azuread_service_principal.hpc_cache[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  for_each = {
    for storageTargetNfsBlob in var.storageTargetsNfsBlob: storageTargetNfsBlob.name => storageTargetNfsBlob
  }
  role_definition_name = "Storage Blob Data Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  principal_id         = data.azuread_service_principal.hpc_cache[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
}

resource "azurerm_hpc_cache" "studio" {
  for_each = {
    for storageCache in local.storageCaches : storageCache.name => storageCache
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
    for storageTargetNfs in local.storageTargetsNfs : "${storageTargetNfs.cacheName}-${storageTargetNfs.name}" => storageTargetNfs
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
    for storageTargetNfsBlob in local.storageTargetsNfsBlob : "${storageTargetNfsBlob.cacheName}-${storageTargetNfsBlob.name}" => storageTargetNfsBlob
  }
  name                 = each.value.name
  resource_group_name  = each.value.resourceGroupName
  cache_name           = each.value.cacheName
  usage_model          = each.value.usageModel
  namespace_path       = each.value.clientPath
  storage_container_id = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}/blobServices/default/containers/${each.value.storage.containerName}"
  depends_on = [
    azurerm_hpc_cache.studio
  ]
}

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

resource "azurerm_private_dns_a_record" "studio_hpc" {
  for_each = {
    for storageCache in local.storageCaches : storageCache.name => storageCache
  }
  name                = "cache-${lower(each.value.regionName)}"
  resource_group_name = data.azurerm_private_dns_zone.studio.resource_group_name
  zone_name           = data.azurerm_private_dns_zone.studio.name
  records             = azurerm_hpc_cache.studio[each.value.name].mount_addresses
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
