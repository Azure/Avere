terraform {
  required_version = ">= 1.3.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.42.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.33.0"
    }
    avere = {
      source  = "hashicorp/avere"
      version = "~>1.3.3"
    }
  }
  backend "azurerm" {
    key = "3.storage.cache"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "global" {
  source = "../0.global/module"
}

variable "resourceGroupName" {
  type = string
}

variable "cacheName" {
  type = string
}

variable "hpcCache" {
  type = object(
    {
      enable     = bool
      throughput = string
      size       = number
      mtuSize    = number
      ntpHost    = string
      dns = object(
        {
          ipAddresses  = list(string)
          searchDomain = string
        }
      )
      encryption = object(
        {
          keyName   = string
          rotateKey = bool
        }
      )
    }
  )
}

variable "vfxtCache" {
  type = object(
    {
      cluster = object(
        {
          nodeSize       = number
          nodeCount      = number
          adminUsername  = string
          adminPassword  = string
          sshPublicKey   = string
          imageId        = string
          customSettings = list(string)
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

variable "storageTargetsNfs" {
  type = list(object(
    {
      name        = string
      storageHost = string
      hpcCache = object(
        {
          usageModel = string
        }
      )
      vfxtCache = object(
        {
          cachePolicy    = string
          nfsConnections = number
          customSettings = list(string)
        }
      )
      namespaceJunctions = list(object(
        {
          storageExport = string
          storagePath   = string
          clientPath    = string
        }
      ))
    }
  ))
}

variable "storageTargetsNfsBlob" {
  type = list(object(
    {
      name       = string
      clientPath = string
      usageModel = string
      storage = object(
        {
          resourceGroupName = string
          accountName       = string
          containerName     = string
        }
      )
    }
  ))
}

variable "computeNetwork" {
  type = object(
    {
      name               = string
      subnetName         = string
      resourceGroupName  = string
      privateDnsZoneName = string
    }
  )
}

data "azurerm_client_config" "provider" {}

data "azurerm_user_assigned_identity" "render" {
  name                = module.global.managedIdentity.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault" "render" {
  count               = module.global.keyVault.name != "" ? 1 : 0
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "admin_username" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.adminUsername
  key_vault_id = data.azurerm_key_vault.render[0].id
}

data "azurerm_key_vault_secret" "admin_password" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.adminPassword
  key_vault_id = data.azurerm_key_vault.render[0].id
}

data "azurerm_key_vault_key" "cache_encryption" {
  count        = module.global.keyVault.name != "" && var.hpcCache.encryption.keyName != "" ? 1 : 0
  name         = var.hpcCache.encryption.keyName != "" ? var.hpcCache.encryption.keyName : module.global.keyVault.keyName.cacheEncryption
  key_vault_id = data.azurerm_key_vault.render[0].id
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName
    key                  = "1.network"
  }
}

# data "azurerm_resource_group" "render" {
#   name = module.global.resourceGroupName
# }

# data "azurerm_resource_group" "network" {
#   name = data.azurerm_virtual_network.compute.resource_group_name
# }

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "cache" {
  name                 = !local.stateExistsNetwork ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.cache].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_private_dns_zone" "network" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.privateDnsZoneName : data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azuread_service_principal" "hpc_cache" {
  count        = var.hpcCache.enable ? 1 : 0
  display_name = "HPC Cache Resource Provider"
}

locals {
  stateExistsNetwork      = var.computeNetwork.name != "" ? false : try(length(data.terraform_remote_state.network.outputs) > 0, false)
  vfxtControllerAddress   = cidrhost(data.azurerm_subnet.cache.address_prefixes[0], 39)
  vfxtVServerFirstAddress = cidrhost(data.azurerm_subnet.cache.address_prefixes[0], 40)
  vfxtVServerAddressCount = 12
}

resource "azurerm_resource_group" "cache" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

##############################################################################
# HPC Cache (https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) #
##############################################################################

resource "azurerm_role_assignment" "storage_account" {
  for_each = {
    for storageTargetNfsBlob in var.storageTargetsNfsBlob : storageTargetNfsBlob.name => storageTargetNfsBlob if var.hpcCache.enable && storageTargetNfsBlob.name != ""
  }
  role_definition_name = "Storage Account Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor
  principal_id         = data.azuread_service_principal.hpc_cache[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.provider.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
}

resource "azurerm_role_assignment" "storage_blob_data" {
  for_each = {
    for storageTargetNfsBlob in var.storageTargetsNfsBlob : storageTargetNfsBlob.name => storageTargetNfsBlob if var.hpcCache.enable && storageTargetNfsBlob.name != ""
  }
  role_definition_name = "Storage Blob Data Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  principal_id         = data.azuread_service_principal.hpc_cache[0].object_id
  scope                = "/subscriptions/${data.azurerm_client_config.provider.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
}

resource "azurerm_hpc_cache" "cache" {
  count               = var.hpcCache.enable ? 1 : 0
  name                = var.cacheName
  resource_group_name = azurerm_resource_group.cache.name
  location            = azurerm_resource_group.cache.location
  subnet_id           = data.azurerm_subnet.cache.id
  sku_name            = var.hpcCache.throughput
  cache_size_in_gb    = var.hpcCache.size
  mtu                 = var.hpcCache.mtuSize
  ntp_server          = var.hpcCache.ntpHost != "" ? var.hpcCache.ntpHost : null
  dynamic "dns" {
    for_each = length(var.hpcCache.dns.ipAddresses) > 0 || var.hpcCache.dns.searchDomain != "" ? [1] : []
    content {
      servers       = var.hpcCache.dns.ipAddresses
      search_domain = var.hpcCache.dns.searchDomain != "" ? var.hpcCache.dns.searchDomain : null
    }
  }
  dynamic "identity" {
    for_each = try(data.azurerm_user_assigned_identity.render.id, "") != "" ? [1] : []
    content {
      type = "UserAssigned"
      identity_ids = [
        data.azurerm_user_assigned_identity.render.id
      ]
    }
  }
  key_vault_key_id                           = var.hpcCache.encryption.keyName != "" ? data.azurerm_key_vault_key.cache_encryption[0].id : null
  automatically_rotate_key_to_latest_enabled = var.hpcCache.encryption.keyName != "" ? var.hpcCache.encryption.rotateKey : null
  depends_on = [
    azurerm_role_assignment.storage_account,
    azurerm_role_assignment.storage_blob_data
  ]
}

resource "azurerm_hpc_cache_nfs_target" "storage" {
  for_each = {
    for storageTargetNfs in var.storageTargetsNfs : storageTargetNfs.name => storageTargetNfs if var.hpcCache.enable && storageTargetNfs.name != ""
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
    for storageTargetNfsBlob in var.storageTargetsNfsBlob : storageTargetNfsBlob.name => storageTargetNfsBlob if var.hpcCache.enable && storageTargetNfsBlob.name != ""
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.cache.name
  cache_name           = azurerm_hpc_cache.cache[0].name
  storage_container_id = "/subscriptions/${data.azurerm_client_config.provider.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}/blobServices/default/containers/${each.value.storage.containerName}"
  usage_model          = each.value.usageModel
  namespace_path       = each.value.clientPath
}

#################################################################################
# Avere vFXT (https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) #
#################################################################################

# resource "azurerm_role_assignment" "managed_identity" {
#   role_definition_name = "Managed Identity Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-operator
#   principal_id         = data.azurerm_user_assigned_identity.render.principal_id
#   scope                = data.azurerm_resource_group.render.id
# }

# resource "azurerm_role_assignment" "network_cache_contributor" {
#   role_definition_name = "Avere Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-contributor
#   principal_id         = data.azurerm_user_assigned_identity.render.principal_id
#   scope                = data.azurerm_resource_group.network.id
# }

# resource "azurerm_role_assignment" "network_cache_operator" {
#   role_definition_name = "Avere Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-operator
#   principal_id         = data.azurerm_user_assigned_identity.render.principal_id
#   scope                = data.azurerm_resource_group.network.id
# }

# resource "azurerm_role_assignment" "cache_managed_identity" {
#   role_definition_name = "Managed Identity Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-operator
#   principal_id         = data.azurerm_user_assigned_identity.render.principal_id
#   scope                = azurerm_resource_group.cache.id
# }

# resource "azurerm_role_assignment" "cache_contributor" {
#   role_definition_name = "Avere Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-contributor
#   principal_id         = data.azurerm_user_assigned_identity.render.principal_id
#   scope                = azurerm_resource_group.cache.id
# }

# resource "azurerm_role_assignment" "cache_operator" {
#   role_definition_name = "Avere Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-operator
#   principal_id         = data.azurerm_user_assigned_identity.render.principal_id
#   scope                = azurerm_resource_group.cache.id
# }

module "vfxt_controller" {
  count                             = var.hpcCache.enable ? 0 : 1
  source                            = "github.com/Azure/Avere/src/terraform/modules/controller3"
  create_resource_group             = false
  resource_group_name               = var.resourceGroupName
  location                          = module.global.regionName
  admin_username                    = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : var.vfxtCache.cluster.adminUsername
  admin_password                    = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : var.vfxtCache.cluster.adminPassword
  ssh_key_data                      = var.vfxtCache.cluster.sshPublicKey != "" ? var.vfxtCache.cluster.sshPublicKey : null
  # user_assigned_managed_identity_id = data.azurerm_user_assigned_identity.render.id
  virtual_network_name              = data.azurerm_virtual_network.compute.name
  virtual_network_resource_group    = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_subnet_name       = data.azurerm_subnet.cache.name
  static_ip_address                 = local.vfxtControllerAddress
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
  count                           = var.hpcCache.enable ? 0 : 1
  vfxt_cluster_name               = lower(var.cacheName)
  azure_resource_group            = var.resourceGroupName
  location                        = module.global.regionName
  image_id                        = var.vfxtCache.cluster.imageId
  node_cache_size                 = var.vfxtCache.cluster.nodeSize
  vfxt_node_count                 = var.vfxtCache.cluster.nodeCount
  azure_network_name              = data.azurerm_virtual_network.compute.name
  azure_network_resource_group    = data.azurerm_virtual_network.compute.resource_group_name
  azure_subnet_name               = data.azurerm_subnet.cache.name
  # user_assigned_managed_identity  = data.azurerm_user_assigned_identity.render.id
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
  global_custom_settings          = var.vfxtCache.cluster.customSettings
  vserver_first_ip                = local.vfxtVServerFirstAddress
  vserver_ip_count                = local.vfxtVServerAddressCount
  timezone                        = var.vfxtCache.localTimezone
  dynamic core_filer {
    for_each = {
      for storageTargetNfs in var.storageTargetsNfs : storageTargetNfs.name => storageTargetNfs if storageTargetNfs.name != ""
    }
    content {
      name                      = core_filer.value["name"]
      fqdn_or_primary_ip        = core_filer.value["storageHost"]
      cache_policy              = core_filer.value["vfxtCache"].cachePolicy
      nfs_connection_multiplier = core_filer.value["vfxtCache"].nfsConnections
      custom_settings           = core_filer.value["vfxtCache"].customSettings
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

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

resource "azurerm_private_dns_a_record" "cache" {
  name                = "cache"
  resource_group_name = data.azurerm_private_dns_zone.network.resource_group_name
  zone_name           = data.azurerm_private_dns_zone.network.name
  records             = var.hpcCache.enable ? azurerm_hpc_cache.cache[0].mount_addresses : avere_vfxt.cache[0].vserver_ip_addresses
  ttl                 = 300
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "cacheName" {
  value = var.cacheName
}

output "cacheControllerAddress" {
  value = var.hpcCache.enable ? "" : length(avere_vfxt.cache) > 0 ? avere_vfxt.cache[0].controller_address : ""
}

output "cacheManagementAddress" {
  value = var.hpcCache.enable ? "" : length(avere_vfxt.cache) > 0 ? avere_vfxt.cache[0].vfxt_management_ip: ""
}

output "cacheMountAddresses" {
  value = var.hpcCache.enable && length(azurerm_hpc_cache.cache) > 0 ? azurerm_hpc_cache.cache[0].mount_addresses : length(avere_vfxt.cache) > 0 ? avere_vfxt.cache[0].vserver_ip_addresses : null
}

output "cachePrivateDnsFqdn" {
  value = azurerm_private_dns_a_record.cache.fqdn
}
