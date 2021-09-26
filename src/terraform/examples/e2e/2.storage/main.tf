terraform {
  required_version = ">= 1.0.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.78.0"
    }
  }
  backend "azurerm" {
    key = "2.storage"
  }
}

provider "azurerm" {
  features {}
}

module "global" {
  source = "../global"
}

variable "resourceGroupName" {
  type = string
}

variable "storageAccounts" {
  type = list(
    object(
      {
        name        = string
        type        = string
        performance = string
        redundancy  = string
        nfsV3Enable = bool
        blobContainers = list(
          object(
            {
              name = string
            }
          )
        )
        fileShares = list(
          object(
            {
              name = string
            }
          )
        )
        messageQueues = list(
          object(
            {
              name = string
            }
          )
        )
        privateEndpoints = list(string)
      }
    )
  )
}

locals {
  blobContainers = flatten([
    for account in var.storageAccounts : [
      for container in account.blobContainers : {
        containerName = container.name
        accountName   = account.name
      }
    ] if account.name != ""
  ])
  fileShares = flatten([
    for account in var.storageAccounts : [
      for share in account.fileShares : {
        shareName   = share.name
        accountName = account.name
      }
    ] if account.name != ""
  ])
  messageQueues = flatten([
    for account in var.storageAccounts : [
      for queue in account.messageQueues : {
        queueName   = queue.name
        accountName = account.name
      }
    ] if account.name != ""
  ])
  privateEndpoints = flatten([
    for account in var.storageAccounts : [
      for endpoint in account.privateEndpoints : {
        endpointType = endpoint
        accountName  = account.name
        accountId    = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${account.name}"
      }
    ] if account.name != ""
  ])
}

resource "azurerm_resource_group" "storage" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.terraformResourceGroupName
    storage_account_name = module.global.terraformStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "1.network"
  }
}

data "azurerm_virtual_network" "network" {
  name                 = data.terraform_remote_state.network.outputs.virtualNetworkName
  resource_group_name  = data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "storage" {
  name                 = data.terraform_remote_state.network.outputs.virtualNetworkSubnetNameStorage
  resource_group_name  = data.terraform_remote_state.network.outputs.resourceGroupName
  virtual_network_name = data.azurerm_virtual_network.network.name
}

data "azurerm_subnet" "cache" {
  name                 = data.terraform_remote_state.network.outputs.virtualNetworkSubnetNameCache
  resource_group_name  = data.terraform_remote_state.network.outputs.resourceGroupName
  virtual_network_name = data.azurerm_virtual_network.network.name
}

data "http" "current_ip_address" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

resource "azurerm_storage_account" "storage" {
  for_each = {
    for x in var.storageAccounts : x.name => x if x.name != ""
  }
  name                     = each.value.name
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_kind             = each.value.type
  account_tier             = each.value.performance
  account_replication_type = each.value.redundancy
  is_hns_enabled           = each.value.nfsV3Enable
  nfsv3_enabled            = each.value.nfsV3Enable
  network_rules {
    default_action             = "Deny"
    ip_rules                   = [jsondecode(data.http.current_ip_address.body).ip]
    virtual_network_subnet_ids = length(each.value.privateEndpoints) == 0 ? [data.azurerm_subnet.storage.id, data.azurerm_subnet.cache.id] : null
  }
}

resource "azurerm_storage_container" "containers" {
  for_each = {
    for x in local.blobContainers : "${x.accountName}.${x.containerName}" => x
  }
  name                 = each.value.containerName
  storage_account_name = each.value.accountName
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_share" "shares" {
  for_each = {
    for x in local.fileShares : "${x.accountName}.${x.shareName}" => x
  }
  name                 = each.value.shareName
  storage_account_name = each.value.accountName
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_queue" "queues" {
  for_each = {
    for x in local.messageQueues : "${x.accountName}.${x.queueName}" => x
  }
  name                 = each.value.queueName
  storage_account_name = each.value.accountName
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_private_dns_zone" "blob" {
  count               = contains(local.privateEndpoints, "blob") ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.storage.name
}

resource "azurerm_private_dns_zone" "file" {
  count               = contains(local.privateEndpoints, "file") ? 1 : 0
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.storage.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  count                 = contains(local.privateEndpoints, "blob") ? 1 : 0
  name                  = "${data.azurerm_virtual_network.network.name}.blob"
  resource_group_name   = azurerm_resource_group.storage.name
  private_dns_zone_name = azurerm_private_dns_zone.blob[count.index].name
  virtual_network_id    = data.azurerm_virtual_network.network.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "file" {
  count                 = contains(local.privateEndpoints, "file") ? 1 : 0
  name                  = "${data.azurerm_virtual_network.network.name}.file"
  resource_group_name   = azurerm_resource_group.storage.name
  private_dns_zone_name = azurerm_private_dns_zone.file[count.index].name
  virtual_network_id    = data.azurerm_virtual_network.network.id
}

resource "azurerm_private_endpoint" "endpoint" {
  for_each = {
    for x in local.privateEndpoints : "${x.accountName}.${x.endpointType}" => x
  }
  name                = "${each.value.accountName}.${each.value.endpointType}"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  subnet_id           = data.azurerm_subnet.storage.id
  private_service_connection {
    name                           = "${each.value.accountName}.${each.value.endpointType}"
    private_connection_resource_id = each.value.accountId
    subresource_names              = [each.value.endpointType]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "${each.value.accountName}.${each.value.endpointType}"
    private_dns_zone_ids = [each.value.endpointType == "blob" ? azurerm_private_dns_zone.blob[0].id : azurerm_private_dns_zone.file[0].id]
  }
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_role_assignment" "storage_account_contributor" {
  for_each = {
    for x in var.storageAccounts : x.name => x if x.name != "" && x.nfsV3Enable
  }
  principal_id         = "831d4223-7a3c-4121-a445-1e423591e57b" // https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview
  role_definition_name = "Storage Account Contributor"          // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-account-contributor
  scope                = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${each.value.name}"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  for_each = {
    for x in var.storageAccounts : x.name => x if x.name != "" && x.nfsV3Enable
  }
  principal_id         = "831d4223-7a3c-4121-a445-1e423591e57b" // https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview
  role_definition_name = "Storage Blob Data Contributor"        // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  scope                = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${each.value.name}"
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
