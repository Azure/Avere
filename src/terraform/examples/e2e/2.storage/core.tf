###################################################################################
# Storage (https://learn.microsoft.com/azure/storage/common/storage-introduction) #
###################################################################################

variable "storageAccounts" {
  type = list(object(
    {
      name                 = string
      type                 = string
      tier                 = string
      redundancy           = string
      enableHttpsOnly      = bool
      enableBlobNfsV3      = bool
      enableLargeFileShare = bool
      blobContainers = list(object(
        {
          name           = string
          rootAcl        = string
          rootAclDefault = string
          dataSource = object(
            {
              accountName   = string
              accountKey    = string
              containerName = string
            }
          )
        }
      ))
      fileShares = list(object(
        {
          name     = string
          tier     = string
          sizeGiB  = number
          protocol = string
          dataSource = object(
            {
              accountName   = string
              accountKey    = string
              containerName = string
            }
          )
        }
      ))
    }
  ))
}

locals {
  serviceEndpointSubnets = !local.stateExistsNetwork ? var.storageNetwork.serviceEndpointSubnets : data.terraform_remote_state.network.outputs.storageEndpointSubnets
  blobContainers = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : {
        name               = blobContainer.name
        rootAcl            = blobContainer.rootAcl
        rootAclDefault     = blobContainer.rootAclDefault
        dataSource         = blobContainer.dataSource
        storageAccountName = storageAccount.name
      }
    ]
  ])
  fileShares = flatten([
    for storageAccount in var.storageAccounts : [
      for fileShare in storageAccount.fileShares : {
        name               = fileShare.name
        tier               = fileShare.tier
        size               = fileShare.sizeGiB
        accessProtocol     = fileShare.protocol
        dataSource         = fileShare.dataSource
        storageAccountName = storageAccount.name
      }
    ]
  ])
}

resource "azurerm_resource_group" "storage" {
  name     = var.resourceGroupName
  location = try(data.azurerm_virtual_network.storage[0].location, data.azurerm_virtual_network.compute.location)
}

resource "azurerm_storage_account" "storage" {
  for_each = {
    for storageAccount in var.storageAccounts : storageAccount.name => storageAccount
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.storage.name
  location                        = azurerm_resource_group.storage.location
  account_kind                    = each.value.type
  account_tier                    = each.value.tier
  account_replication_type        = each.value.redundancy
  enable_https_traffic_only       = each.value.enableHttpsOnly
  is_hns_enabled                  = each.value.enableBlobNfsV3
  nfsv3_enabled                   = each.value.enableBlobNfsV3
  large_file_share_enabled        = each.value.enableLargeFileShare ? true : null
  allow_nested_items_to_be_public = false
  network_rules {
    default_action = "Deny"
    virtual_network_subnet_ids = [
      for serviceEndpointSubnet in local.serviceEndpointSubnets :
        "${data.azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${serviceEndpointSubnet.virtualNetworkName}/subnets/${serviceEndpointSubnet.name}"
    ]
    ip_rules = [
      jsondecode(data.http.client_address.response_body).ip
    ]
  }
}

resource "time_sleep" "storage_data" {
  for_each = {
    for storageAccount in var.storageAccounts : storageAccount.name => storageAccount
  }
  create_duration = "30s"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_container" "containers" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}.${blobContainer.name}" => blobContainer
  }
  name                 = each.value.name
  storage_account_name = each.value.storageAccountName
  provisioner "local-exec" {
    command = "az storage fs access set --account-name ${each.value.storageAccountName} --file-system ${each.value.name} --path / --acl ${each.value.rootAcl}"
  }
  provisioner "local-exec" {
    command = "az storage fs access set --account-name ${each.value.storageAccountName} --file-system ${each.value.name} --path / --acl ${each.value.rootAclDefault}"
  }
  provisioner "local-exec" {
    command = each.value.dataSource.accountName == "" ? "az storage container show --account-name ${each.value.storageAccountName} --name ${each.value.name}" : "az storage copy --source-account-name ${each.value.dataSource.accountName} --source-account-key ${each.value.dataSource.accountKey} --source-container ${each.value.dataSource.containerName} --recursive --account-name ${each.value.storageAccountName} --destination-container ${each.value.name}"
  }
  depends_on = [
    time_sleep.storage_data
  ]
}

resource "azurerm_storage_share" "shares" {
  for_each = {
    for fileShare in local.fileShares : "${fileShare.storageAccountName}.${fileShare.name}" => fileShare
  }
  name                 = each.value.name
  access_tier          = each.value.tier
  storage_account_name = each.value.storageAccountName
  enabled_protocol     = each.value.accessProtocol
  quota                = each.value.size
  provisioner "local-exec" {
    command = each.value.dataSource.accountName == "" ? "az storage share show --account-name ${each.value.storageAccountName} --name ${each.value.name}" : "az storage copy --source-account-name ${each.value.dataSource.accountName} --source-account-key ${each.value.dataSource.accountKey} --source-container ${each.value.dataSource.containerName} --recursive --account-name ${each.value.storageAccountName} --destination-share ${each.value.name}"
  }
  depends_on = [
    time_sleep.storage_data
  ]
}
