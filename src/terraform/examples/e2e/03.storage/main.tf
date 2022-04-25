terraform {
  required_version = ">= 1.1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.3.0"
    }
  }
  backend "azurerm" {
    key = "03.storage"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

module "global" {
  source = "../00.global"
}

variable "resourceGroupName" {
  type = string
}

variable "storageAccounts" {
  type = list(
    object(
      {
        name                 = string
        type                 = string
        tier                 = string
        redundancy           = string
        enableBlobNfsV3      = bool
        enableLargeFileShare = bool
        enableSecureTransfer = bool
        privateEndpointTypes = list(string)
        blobContainers = list(
          object(
            {
              name             = string
              accessType       = string
              localDirectories = list(string)
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

variable "virtualNetwork" {
  type = object(
    {
      name              = string
      resourceGroupName = string
      subnetNameStorage = string
      subnetNameCache   = string
    }
  )
}

data "terraform_remote_state" "network" {
  count   = var.virtualNetwork.name != "" ? 0 : 1
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "02.network"
  }
}

data "azurerm_virtual_network" "network" {
  name                 = var.virtualNetwork.name != "" ? var.virtualNetwork.name : data.terraform_remote_state.network[0].outputs.virtualNetwork.name
  resource_group_name  = var.virtualNetwork.name != "" ? var.virtualNetwork.resourceGroupName : data.terraform_remote_state.network[0].outputs.resourceGroupName
}

data "azurerm_subnet" "storage" {
  name                 = var.virtualNetwork.name != "" ? var.virtualNetwork.subnetNameStorage : data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets[data.terraform_remote_state.network[0].outputs.virtualNetworkSubnetIndex.storage].name
  resource_group_name  = var.virtualNetwork.name != "" ? var.virtualNetwork.resourceGroupName : data.terraform_remote_state.network[0].outputs.resourceGroupName
  virtual_network_name = var.virtualNetwork.name != "" ? var.virtualNetwork.name : data.terraform_remote_state.network[0].outputs.virtualNetwork.name
}

data "http" "current_ip_address" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  privateDnsZones = distinct(flatten([
    for storageAccount in var.storageAccounts : [
      for privateEndpointType in storageAccount.privateEndpointTypes : {
        privateDnsZoneName = "privatelink.${privateEndpointType}.core.windows.net"
      }
    ] if storageAccount.name != ""
  ]))
  privateEndpoints = flatten([
    for storageAccount in var.storageAccounts : [
      for privateEndpointType in storageAccount.privateEndpointTypes : {
        privateEndpointType = privateEndpointType
        privateDnsZoneName  = "privatelink.${privateEndpointType}.core.windows.net"
        storageAccountName  = storageAccount.name
        storageAccountId    = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${storageAccount.name}"
      }
    ] if storageAccount.name != ""
  ])
  serviceEndpointSubnets = var.virtualNetwork.name != "" ? [ var.virtualNetwork.subnetNameStorage, var.virtualNetwork.subnetNameCache ] : [
    for subnet in data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets : subnet.name if contains(subnet.serviceEndpoints, "Microsoft.Storage")
  ]
  blobContainers = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : {
        blobContainerName       = blobContainer.name
        blobContainerAccessType = blobContainer.accessType
        storageAccountName      = storageAccount.name
      }
    ] if storageAccount.name != ""
  ])
  blobRootFiles = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : [
        for blob in fileset(blobContainer.name, "*") : {
          blobName           = blob
          blobContainerName  = blobContainer.name
          storageAccountName = storageAccount.name
        }
      ]
    ] if storageAccount.name != ""
  ])
  blobDirectoryFiles = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : [
        for blobDirectory in blobContainer.localDirectories : [
          for blob in fileset(blobContainer.name, "/${blobDirectory}/**") : {
            blobName           = blob
            blobContainerName  = blobContainer.name
            storageAccountName = storageAccount.name
          }
        ]
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
  name                      = each.value.name
  resource_group_name       = azurerm_resource_group.storage.name
  location                  = azurerm_resource_group.storage.location
  account_kind              = each.value.type
  account_tier              = each.value.tier
  account_replication_type  = each.value.redundancy
  is_hns_enabled            = each.value.enableBlobNfsV3
  nfsv3_enabled             = each.value.enableBlobNfsV3
  large_file_share_enabled  = each.value.enableLargeFileShare ? true : null
  enable_https_traffic_only = each.value.enableSecureTransfer
  dynamic "network_rules" {
    for_each = each.value.enableBlobNfsV3 ? [1] : [] 
    content {
      default_action = "Deny"
      virtual_network_subnet_ids = [
        for x in local.serviceEndpointSubnets : "${data.azurerm_virtual_network.network.id}/subnets/${x}"
      ]
      ip_rules = [
        jsondecode(data.http.current_ip_address.body).ip
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each = {
    for x in local.privateDnsZones : x.privateDnsZoneName => x
  }
  name                = each.value.privateDnsZoneName
  resource_group_name = azurerm_resource_group.storage.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "zone_links" {
  for_each = {
    for x in local.privateDnsZones : x.privateDnsZoneName => x
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
  container_access_type = each.value.blobContainerAccessType
  storage_account_name  = each.value.storageAccountName
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_blob" "blobs" {
  for_each = {
    for x in setunion(local.blobRootFiles, local.blobDirectoryFiles) : "${x.storageAccountName}.${x.blobName}" => x
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

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "storageAccounts" {
  value = var.storageAccounts
}

output "privateEndpointTypes" {
  value = distinct(flatten([
    for storageAccount in var.storageAccounts : storageAccount.privateEndpointTypes if storageAccount.name != ""
  ]))
}
