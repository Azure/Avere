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
      privateEndpointTypes = list(string)
      fileShares = list(object(
        {
          name           = string
          sizeGiB        = number
          accessTier     = string
          accessProtocol = string
          enableFileLoad = bool
        }
      ))
      blobContainers = list(object(
        {
          name           = string
          rootAcl        = string
          rootAclDefault = string
          enableFileLoad = bool

        }
      ))
    }
  ))
}

locals {
  serviceEndpointSubnets = !local.stateExistsNetwork ? var.storageNetwork.serviceEndpointSubnets : data.terraform_remote_state.network.outputs.storageEndpointSubnets
  privateEndpoints = flatten([
    for storageAccount in var.storageAccounts : [
      for privateEndpointType in storageAccount.privateEndpointTypes : {
        storageAccountName = storageAccount.name
        storageAccountId   = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${azurerm_resource_group.storage.name}/providers/Microsoft.Storage/storageAccounts/${storageAccount.name}"
        type               = privateEndpointType
        dnsZoneId          = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${data.azurerm_resource_group.network.name}/providers/Microsoft.Network/privateDnsZones/privatelink.${privateEndpointType}.core.windows.net"
      }
    ]
  ])
  fileShares = flatten([
    for storageAccount in var.storageAccounts : [
      for fileShare in storageAccount.fileShares : {
        name               = fileShare.name
        size               = fileShare.sizeGiB
        accessTier         = fileShare.accessTier
        accessProtocol     = fileShare.accessProtocol
        storageAccountName = storageAccount.name
        enableFileLoad     = fileShare.enableFileLoad
      }
    ]
  ])
  blobStorageAccounts = [
    for storageAccount in var.storageAccounts : storageAccount if storageAccount.type == "StorageV2" || storageAccount.type == "BlockBlobStorage"
  ]
  blobContainers = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : {
        name               = blobContainer.name
        rootAcl            = blobContainer.rootAcl
        rootAclDefault     = blobContainer.rootAclDefault
        storageAccountName = storageAccount.name
        enableFileLoad     = blobContainer.enableFileLoad
        enableFileSystem   = storageAccount.enableBlobNfsV3
      }
    ]
  ])
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

resource "azurerm_private_endpoint" "storage" {
  for_each = {
    for privateEndpoint in local.privateEndpoints : "${privateEndpoint.storageAccountName}.${privateEndpoint.type}" => privateEndpoint
  }
  name                = each.value.storageAccountName
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  subnet_id           = local.storageSubnet.id
  private_service_connection {
    name                           = each.value.storageAccountName
    private_connection_resource_id = each.value.storageAccountId
    is_manual_connection           = false
    subresource_names = [
      each.value.type
    ]
  }
  private_dns_zone_group {
    name = each.value.storageAccountName
    private_dns_zone_ids = [
      each.value.dnsZoneId
    ]
  }
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_share" "core" {
  for_each = {
    for fileShare in local.fileShares : "${fileShare.storageAccountName}.${fileShare.name}" => fileShare
  }
  name                 = each.value.name
  access_tier          = each.value.accessTier
  enabled_protocol     = each.value.accessProtocol
  storage_account_name = each.value.storageAccountName
  quota                = each.value.size
  depends_on = [
    azurerm_private_endpoint.storage
  ]
}

resource "terraform_data" "file_share_load_root" {
  for_each = {
    for fileShare in local.fileShares : "${fileShare.storageAccountName}.${fileShare.name}" => fileShare if var.fileLoadSource.accountName != "" && var.fileLoadSource.blobName == "" && fileShare.enableFileLoad
  }
  provisioner "local-exec" {
    command = "az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --recursive --account-name ${each.value.storageAccountName} --destination-share ${each.value.name}"
  }
  depends_on = [
    azurerm_storage_share.core
   ]
}

resource "terraform_data" "file_share_load_blob" {
  for_each = {
    for fileShare in local.fileShares : "${fileShare.storageAccountName}.${fileShare.name}" => fileShare if var.fileLoadSource.accountName != "" && var.fileLoadSource.blobName != "" && fileShare.enableFileLoad
  }
  provisioner "local-exec" {
    command = "az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --source-blob ${var.fileLoadSource.blobName} --recursive --account-name ${each.value.storageAccountName} --destination-share ${each.value.name} --destination-file-path ${var.fileLoadSource.blobName}"
  }
  depends_on = [
    azurerm_storage_share.core
   ]
}

resource "azurerm_storage_container" "core" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}.${blobContainer.name}" => blobContainer
  }
  name                 = each.value.name
  storage_account_name = each.value.storageAccountName
  depends_on = [
    azurerm_private_endpoint.storage
  ]
}

resource "terraform_data" "storage_container_permission" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}.${blobContainer.name}" => blobContainer if blobContainer.enableFileSystem
  }
  provisioner "local-exec" {
    command = "az storage fs access set --account-name ${each.value.storageAccountName} --file-system ${each.value.name} --path / --acl ${each.value.rootAcl}"
  }
  provisioner "local-exec" {
    command = "az storage fs access set --account-name ${each.value.storageAccountName} --file-system ${each.value.name} --path / --acl ${each.value.rootAclDefault}"
  }
  depends_on = [
    azurerm_storage_container.core
   ]
}

resource "terraform_data" "blob_container_load_root" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}.${blobContainer.name}" => blobContainer if var.fileLoadSource.accountName != "" && var.fileLoadSource.blobName == "" && blobContainer.enableFileLoad
  }
  provisioner "local-exec" {
    command = "az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --recursive --account-name ${each.value.storageAccountName} --destination-container ${each.value.name}"
  }
  depends_on = [
    azurerm_storage_container.core
   ]
}

resource "terraform_data" "blob_container_load_blob" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}.${blobContainer.name}" => blobContainer if var.fileLoadSource.accountName != "" && var.fileLoadSource.blobName != "" && blobContainer.enableFileLoad
  }
  provisioner "local-exec" {
    command = "az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --source-blob ${var.fileLoadSource.blobName} --recursive --account-name ${each.value.storageAccountName} --destination-container ${each.value.name} --destination-blob ${var.fileLoadSource.blobName}"
  }
  depends_on = [
    azurerm_storage_container.core
   ]
}

output "blobStorageAccounts" {
  value = local.blobStorageAccounts
}
