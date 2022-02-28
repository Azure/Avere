terraform {
  required_version = ">= 1.1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.98.0"
    }
  }
  backend "azurerm" {
    key = "3.storage"
  }
}

provider "azurerm" {
  features {}
}

module "global" {
  source = "../0.global"
}

variable "resourceGroupName" {
  type = string
}

variable "storageAccounts" {
  type = list(
    object(
      {
        name                  = string
        type                  = string
        redundancy            = string
        performance           = string
        enableBlobNfsV3       = bool
        enableLargeFileShares = bool
        privateEndpoints      = list(string)
        blobContainers = list(
          object(
            {
              name   = string
              access = string
            }
          )
        )
        fileShares = list(
          object(
            {
              name     = string
              sizeGiB  = number
              protocol = string
            }
          )
        )
      }
    )
  )
}

variable "netAppAccounts" {
  type = list(
    object(
      {
        name = string
        capacityPools = list(
          object(
            {
              name         = string
              serviceLevel = string
              sizeTB       = number
              volumes = list(
                object(
                  {
                    name           = string
                    mountPath      = string
                    serviceLevel   = string
                    sizeGB         = number
                    protocols      = list(string)
                    exportPolicies = list(
                      object(
                        {
                          ruleIndex      = number
                          readOnly       = bool
                          readWrite      = bool
                          rootAccess     = bool
                          protocols      = list(string)
                          allowedClients = list(string)
                        }
                      )
                    )
                  }
                )
              )
            }
          )
        )
      }
    )
  )
}

variable "virtualNetwork" {
  type = object(
    {
      name              = string
      subnetName        = string
      resourceGroupName = string
    }
  )
}

locals {
  privateDnsZones = flatten([
    for storageAccount in var.storageAccounts : [
      for privateEndpoint in storageAccount.privateEndpoints : {
        privateDnsZoneName = "privatelink.${privateEndpoint}.core.windows.net"
      }
    ] if storageAccount.name != ""
  ])
  privateEndpoints = flatten([
    for storageAccount in var.storageAccounts : [
      for privateEndpoint in storageAccount.privateEndpoints : {
        privateEndpointType = privateEndpoint
        privateDnsZoneName  = "privatelink.${privateEndpoint}.core.windows.net"
        storageAccountName  = storageAccount.name
        storageAccountId    = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${storageAccount.name}"
      }
    ] if storageAccount.name != ""
  ])
  privateEndpointTypes = flatten([
    for storageAccount in var.storageAccounts : storageAccount.privateEndpoints if storageAccount.name != ""
  ])
  blobContainers = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : {
        blobContainerName   = blobContainer.name
        blobContainerAccess = blobContainer.access
        storageAccountName  = storageAccount.name
      }
    ] if storageAccount.name != ""
  ])
  blobs = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : [
        for blob in fileset(blobContainer.name, "**") : {
          blobName           = blob
          blobContainerName  = blobContainer.name
          storageAccountName = storageAccount.name
        }
      ]
    ] if storageAccount.name != ""
  ])
  fileShares = flatten([
    for storageAccount in var.storageAccounts : [
      for fileShare in storageAccount.fileShares : {
        fileShareName      = fileShare.name
        fileShareSize      = fileShare.sizeGiB
        fileAccessProtocol = fileShare.protocol
        storageAccountName = storageAccount.name
      }
    ] if storageAccount.name != ""
  ])
  hpcCachePrincipalId = "831d4223-7a3c-4121-a445-1e423591e57b"
  netAppCapacityPools = flatten([
    for netAppAccount in var.netAppAccounts : [
      for capacityPool in netAppAccount.capacityPools : {
        netAppAccountName = netAppAccount.name
        capacityPool      = capacityPool
      } if capacityPool.name != ""
    ] if netAppAccount.name != ""
  ])
  netAppPoolVolumes = flatten([
    for netAppAccount in var.netAppAccounts : [
      for capacityPool in netAppAccount.capacityPools : [
        for poolVolume in capacityPool.volumes : {
          netAppAccountName = netAppAccount.name
          capacityPoolName  = capacityPool.name
          poolVolume        = poolVolume
        } if poolVolume.name != ""
      ] if capacityPool.name != ""
    ] if netAppAccount.name != ""
  ])
}

data "terraform_remote_state" "network" {
  count   = var.virtualNetwork.name == "" ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
  }
}

data "azurerm_virtual_network" "network" {
  name                 = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.virtualNetwork.name : var.virtualNetwork.name
  resource_group_name  = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.resourceGroupName : var.virtualNetwork.resourceGroupName
}

data "azurerm_subnet" "storage" {
  name                 = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets[data.terraform_remote_state.network[0].outputs.virtualNetworkSubnetIndex.storage].name : var.virtualNetwork.subnetName
  resource_group_name  = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.resourceGroupName : var.virtualNetwork.resourceGroupName
  virtual_network_name = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.virtualNetwork.name : var.virtualNetwork.name
}

data "http" "current_ip_address" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

resource "azurerm_resource_group" "storage" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

########################################################################################
# Storage (https://docs.microsoft.com/en-us/azure/storage/common/storage-introduction) #
########################################################################################

resource "azurerm_storage_account" "storage" {
  for_each = {
    for x in var.storageAccounts : x.name => x if x.name != ""
  }
  name                     = each.value.name
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_kind             = each.value.type
  account_replication_type = each.value.redundancy
  account_tier             = each.value.performance
  is_hns_enabled           = each.value.enableBlobNfsV3
  nfsv3_enabled            = each.value.enableBlobNfsV3
  large_file_share_enabled = each.value.enableLargeFileShares ? true : null
  dynamic "network_rules" {
    for_each = each.value.enableBlobNfsV3 ? [1] : [] 
    content {
      default_action = "Deny"
      virtual_network_subnet_ids = [
        for x in data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets : "${data.azurerm_virtual_network.network.id}/subnets/${x.name}" if contains(x.serviceEndpoints, "Microsoft.Storage")
      ]
      ip_rules = [
        jsondecode(data.http.current_ip_address.body).ip
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each = {
    for x in distinct(local.privateDnsZones) : x.privateDnsZoneName => x
  }
  name                = each.value.privateDnsZoneName
  resource_group_name = azurerm_resource_group.storage.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "zone_links" {
  for_each = {
    for x in distinct(local.privateDnsZones) : x.privateDnsZoneName => x
  }
  name                  = data.azurerm_virtual_network.network.name
  resource_group_name   = azurerm_resource_group.storage.name
  private_dns_zone_name = each.value.privateDnsZoneName
  virtual_network_id    = data.azurerm_virtual_network.network.id
  depends_on = [
    azurerm_private_dns_zone.zones
  ]
}

resource "azurerm_private_endpoint" "storage" {
  for_each = {
    for x in local.privateEndpoints : "${x.storageAccountName}.${x.privateEndpointType}" => x
  }
  name                = "${each.value.storageAccountName}.${each.value.privateEndpointType}"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  subnet_id           = data.azurerm_subnet.storage.id
  private_service_connection {
    name                           = each.value.storageAccountName
    private_connection_resource_id = each.value.storageAccountId
    is_manual_connection           = false
    subresource_names = [
      each.value.privateEndpointType
    ]
  }
  private_dns_zone_group {
    name = each.value.storageAccountName
    private_dns_zone_ids = [
      "${azurerm_resource_group.storage.id}/providers/Microsoft.Network/privateDnsZones/${each.value.privateDnsZoneName}"
    ]
  }
  depends_on = [
    azurerm_storage_account.storage,
    azurerm_private_dns_zone_virtual_network_link.zone_links
  ]
}

# https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-account-contributor
resource "azurerm_role_assignment" "storage_account_contributor" {
  for_each = {
    for x in var.storageAccounts : x.name => x if x.enableBlobNfsV3 && x.name != "" 
  }
  role_definition_name = "Storage Account Contributor"
  principal_id         = local.hpcCachePrincipalId
  scope                = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${each.value.name}"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

# https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  for_each = {
    for x in var.storageAccounts : x.name => x if x.enableBlobNfsV3 && x.name != "" 
  }
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.hpcCachePrincipalId
  scope                = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${each.value.name}"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_container" "containers" {
  for_each = {
    for x in local.blobContainers : "${x.storageAccountName}.${x.blobContainerName}" => x
  }
  name                  = each.value.blobContainerName
  container_access_type = each.value.blobContainerAccess
  storage_account_name  = each.value.storageAccountName
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_blob" "blobs" {
  for_each = {
    for x in local.blobs : "${x.storageAccountName}.${x.blobName}" => x
  }
  name                   = each.value.blobName
  storage_account_name   = each.value.storageAccountName
  storage_container_name = each.value.blobContainerName
  source                 = "${path.cwd}/${each.value.blobContainerName}/${each.value.blobName}"
  type                   = "Block"
  depends_on = [
    azurerm_storage_container.containers
  ]
}

resource "azurerm_storage_share" "shares" {
  for_each = {
    for x in local.fileShares : "${x.storageAccountName}.${x.fileShareName}" => x
  }
  name                 = each.value.fileShareName
  storage_account_name = each.value.storageAccountName
  enabled_protocol     = each.value.fileAccessProtocol
  quota                = each.value.fileShareSize
  depends_on = [
    azurerm_storage_account.storage
  ]
}

#######################################################################################################
# Hammerspace (https://azuremarketplace.microsoft.com/en-us/marketplace/apps/hammerspace.hammerspace) #
#######################################################################################################

# TBD

############################################################################################################
# NetApp Files (https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-introduction) #
############################################################################################################

resource "azurerm_netapp_account" "storage" {
  for_each = {
    for x in var.netAppAccounts : x.name => x if x.name != ""
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
}

resource "azurerm_netapp_pool" "storage" {
  for_each = {
    for x in local.netAppCapacityPools : "${x.netAppAccountName}.${x.capacityPool.name}" => x
  }
  name                = each.value.capacityPool.name
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  account_name        = each.value.netAppAccountName
  service_level       = each.value.capacityPool.serviceLevel
  size_in_tb          = each.value.capacityPool.sizeTB
  depends_on = [
    azurerm_netapp_account.storage
  ]
}

resource "azurerm_netapp_volume" "storage" {
  for_each = {
    for x in local.netAppPoolVolumes : "${x.netAppAccountName}.${x.capacityPoolName}.${x.poolVolume.name}" => x
  }
  name                = each.value.poolVolume.name
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  account_name        = each.value.netAppAccountName
  pool_name           = each.value.capacityPoolName
  volume_path         = each.value.poolVolume.mountPath
  service_level       = each.value.poolVolume.serviceLevel
  storage_quota_in_gb = each.value.poolVolume.sizeGB
  protocols           = each.value.poolVolume.protocols
  subnet_id           = data.azurerm_subnet.storage.id
  dynamic "export_policy_rule" {
    for_each = each.value.poolVolume.exportPolicies 
    content {
      rule_index          = export_policy_rule.value["ruleIndex"]
      unix_read_only      = export_policy_rule.value["readOnly"]
      unix_read_write     = export_policy_rule.value["readWrite"]
      root_access_enabled = export_policy_rule.value["rootAccess"]
      protocols_enabled   = export_policy_rule.value["protocols"]
      allowed_clients     = export_policy_rule.value["allowedClients"]
    }
  }
  depends_on = [
    azurerm_netapp_pool.storage
  ]
}

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "storageAccounts" {
  value = var.storageAccounts
}

output "netAppAccounts" {
  value = var.netAppAccounts
}
