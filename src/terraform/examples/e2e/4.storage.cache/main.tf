terraform {
  required_version = ">= 1.3.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.33.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.30.0"
    }
    avere = {
      source  = "hashicorp/avere"
      version = "~>1.3.3"
    }
  }
  backend "azurerm" {
    key = "4.storage.cache"
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
  source = "../0.global"
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
      encryption = object(
        {
          enable    = bool
          rotateKey = bool
        }
      )
    }
  )
}

variable "vfxtCache" {
  type = object(
    {
      localTimezone = string
      cluster = object(
        {
          nodeSize       = number
          nodeCount      = number
          adminUsername  = string
          sshPublicKey   = string
          imageId        = string
          customSettings = list(string)
        }
      )
      controller = object(
        {
          adminUsername = string
          sshPublicKey  = string
          imageId       = string
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
      enableMarketplaceAgreement = bool
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
      privateDns = object(
        {
          zoneName               = string
          enableAutoRegistration = bool
        }
      )
    }
  )
}

data "azurerm_client_config" "current" {}

data "azurerm_user_assigned_identity" "solution" {
  name                = module.global.managedIdentityName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault" "solution" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_key" "cache_encryption" {
  name         = module.global.keyVaultKeyNameCacheEncryption
  key_vault_id = data.azurerm_key_vault.solution.id
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
  }
}

data "azurerm_resource_group" "identity" {
  name = module.global.securityResourceGroupName
}

data "azurerm_resource_group" "network" {
  name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "cache" {
  name                 = !local.stateExistsNetwork ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetworkSubnetIndex.cache].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_private_dns_zone" "network" {
  name                = data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azuread_service_principal" "hpc_cache" {
  display_name = "HPC Cache Resource Provider"
}

locals {
  stateExistsNetwork      = try(length(data.terraform_remote_state.network.outputs) >= 0, false)
  deployPrivateDnsZone    = !local.stateExistsNetwork && var.computeNetwork.privateDns.zoneName != ""
  vfxtControllerAddress   = !local.stateExistsNetwork ? "" : cidrhost(data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetworkSubnetIndex.cache].addressSpace[0], 39)
  vfxtVServerFirstAddress = !local.stateExistsNetwork ? "" : cidrhost(data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetworkSubnetIndex.cache].addressSpace[0], 40)
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
  principal_id         = data.azuread_service_principal.hpc_cache.object_id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
}

resource "azurerm_role_assignment" "storage_blob_data" {
  for_each = {
    for storageTargetNfsBlob in var.storageTargetsNfsBlob : storageTargetNfsBlob.name => storageTargetNfsBlob if var.hpcCache.enable && storageTargetNfsBlob.name != ""
  }
  role_definition_name = "Storage Blob Data Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  principal_id         = data.azuread_service_principal.hpc_cache.object_id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}"
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
  ntp_server          = var.hpcCache.ntpHost
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.solution.id
    ]
  }
  key_vault_key_id                           = var.hpcCache.encryption.enable ? data.azurerm_key_vault_key.cache_encryption.id : null
  automatically_rotate_key_to_latest_enabled = var.hpcCache.encryption.enable ? var.hpcCache.encryption.rotateKey : null
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
  storage_container_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${each.value.storage.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${each.value.storage.accountName}/blobServices/default/containers/${each.value.storage.containerName}"
  usage_model          = each.value.usageModel
  namespace_path       = each.value.clientPath
}

#################################################################################
# Avere vFXT (https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) #
#################################################################################

data "azurerm_key_vault_secret" "admin_password" {
  name         = module.global.keyVaultSecretNameAdminPassword
  key_vault_id = data.azurerm_key_vault.solution.id
}

resource "azurerm_role_assignment" "identity" {
  role_definition_name = "Managed Identity Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-operator
  principal_id         = data.azurerm_user_assigned_identity.solution.principal_id
  scope                = data.azurerm_resource_group.identity.id
}

resource "azurerm_role_assignment" "network" {
  role_definition_name = "Avere Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-contributor
  principal_id         = data.azurerm_user_assigned_identity.solution.principal_id
  scope                = data.azurerm_resource_group.network.id
}

resource "azurerm_role_assignment" "cache_identity" {
  role_definition_name = "Managed Identity Operator" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-operator
  principal_id         = data.azurerm_user_assigned_identity.solution.principal_id
  scope                = azurerm_resource_group.cache.id
}

resource "azurerm_role_assignment" "cache_contributor" {
  role_definition_name = "Avere Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#avere-contributor
  principal_id         = data.azurerm_user_assigned_identity.solution.principal_id
  scope                = azurerm_resource_group.cache.id
}

resource "azurerm_marketplace_agreement" "cache" {
  count     = var.vfxtCache.enableMarketplaceAgreement && !var.hpcCache.enable ? 1 : 0
  publisher = "Microsoft-Avere"
  offer     = "vFXT"
  plan      = "Avere-vFXT-Controller"
}

module "vfxt_controller" {
  count                             = var.hpcCache.enable ? 0 : 1
  source                            = "github.com/Azure/Avere/src/terraform/modules/controller3"
  create_resource_group             = false
  resource_group_name               = var.resourceGroupName
  location                          = module.global.regionName
  admin_username                    = var.vfxtCache.controller.adminUsername
  admin_password                    = data.azurerm_key_vault_secret.admin_password.value
  ssh_key_data                      = var.vfxtCache.controller.sshPublicKey != "" ? var.vfxtCache.controller.sshPublicKey : null
  virtual_network_name              = data.azurerm_virtual_network.compute.name
  virtual_network_resource_group    = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_subnet_name       = data.azurerm_subnet.cache.name
  static_ip_address                 = local.vfxtControllerAddress
  user_assigned_managed_identity_id = data.azurerm_user_assigned_identity.solution.id
  image_id                          = var.vfxtCache.controller.imageId
  depends_on = [
    azurerm_resource_group.cache,
    azurerm_role_assignment.identity,
    azurerm_role_assignment.network,
    azurerm_role_assignment.cache_identity,
    azurerm_role_assignment.cache_contributor
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
  controller_address              = module.vfxt_controller[count.index].controller_address
  controller_admin_username       = module.vfxt_controller[count.index].controller_username
  controller_admin_password       = data.azurerm_key_vault_secret.admin_password.value
  vfxt_admin_password             = data.azurerm_key_vault_secret.admin_password.value
  vfxt_ssh_key_data               = var.vfxtCache.cluster.sshPublicKey != "" ? var.vfxtCache.cluster.sshPublicKey : null
  support_uploads_company_name    = var.vfxtCache.support.companyName
  enable_support_uploads          = var.vfxtCache.support.enableLogUpload
  enable_secure_proactive_support = var.vfxtCache.support.enableProactive
  enable_rolling_trace_data       = var.vfxtCache.support.rollingTraceFlag != ""
  rolling_trace_flag              = var.vfxtCache.support.rollingTraceFlag
  global_custom_settings          = var.vfxtCache.cluster.customSettings
  vserver_first_ip                = local.vfxtVServerFirstAddress
  vserver_ip_count                = local.vfxtVServerAddressCount
  user_assigned_managed_identity  = data.azurerm_user_assigned_identity.solution.id
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
    azurerm_marketplace_agreement.cache,
    module.vfxt_controller
  ]
}

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

resource "azurerm_private_dns_zone" "network" {
  count               = local.deployPrivateDnsZone ? 1 : 0
  name                = var.computeNetwork.privateDns.zoneName
  resource_group_name = azurerm_resource_group.cache.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network" {
  count                 = local.deployPrivateDnsZone ? 1 : 0
  name                  = var.computeNetwork.name
  resource_group_name   = azurerm_resource_group.cache.name
  private_dns_zone_name = azurerm_private_dns_zone.network[0].name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
  registration_enabled  = var.computeNetwork.privateDns.enableAutoRegistration
}

resource "azurerm_private_dns_a_record" "cache" {
  name                = "cache"
  resource_group_name = local.deployPrivateDnsZone ? azurerm_private_dns_zone.network[0].resource_group_name : data.azurerm_private_dns_zone.network.resource_group_name
  zone_name           = local.deployPrivateDnsZone ? azurerm_private_dns_zone.network[0].name : data.azurerm_private_dns_zone.network.name
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
