###################################################################################
# Storage (https://learn.microsoft.com/azure/storage/common/storage-introduction) #
###################################################################################

variable "storageAccounts" {
  type = list(object({
    enable               = bool
    name                 = string
    type                 = string
    tier                 = string
    redundancy           = string
    enableHttpsOnly      = bool
    enableBlobNfsV3      = bool
    enableLargeFileShare = bool
    privateEndpointTypes = list(string)
    blobContainers = list(object({
      enable    = bool
      name      = string
      loadFiles = bool
      fileSystem = object({
        enable  = bool
        rootAcl = string
      })
    }))
    fileShares = list(object({
      enable         = bool
      name           = string
      sizeGB         = number
      accessTier     = string
      accessProtocol = string
      loadFiles      = bool
    }))
  }))
}

locals {
  serviceEndpointSubnets = var.storageNetwork.enable ? var.storageNetwork.serviceEndpointSubnets : data.terraform_remote_state.network.outputs.storageEndpointSubnets
  privateEndpoints = flatten([
    for storageAccount in var.storageAccounts : [
      for privateEndpointType in storageAccount.privateEndpointTypes : {
        type               = privateEndpointType
        storageAccountName = storageAccount.name
        storageAccountId   = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${storageAccount.name}"
        dnsZoneId          = "${data.azurerm_resource_group.network.id}/providers/Microsoft.Network/privateDnsZones/privatelink.${privateEndpointType}.core.windows.net"
      }
    ] if storageAccount.enable
  ])
  blobStorageAccount = one([
    for storageAccount in var.storageAccounts : merge(storageAccount, {
      resourceGroupName = var.resourceGroupName
    }) if storageAccount.enable && storageAccount.type == "StorageV2"
  ])
  blobContainers = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : {
        name               = blobContainer.name
        loadFiles          = blobContainer.loadFiles
        fileSystemEnable   = blobContainer.fileSystem.enable
        fileSystemRootAcl  = blobContainer.fileSystem.rootAcl
        storageAccountName = storageAccount.name
      } if blobContainer.enable
    ] if storageAccount.enable
  ])
  fileShares = flatten([
    for storageAccount in var.storageAccounts : [
      for fileShare in storageAccount.fileShares : {
        name               = fileShare.name
        size               = fileShare.sizeGB
        accessTier         = fileShare.accessTier
        accessProtocol     = fileShare.accessProtocol
        loadFiles          = fileShare.loadFiles
        storageAccountName = storageAccount.name
      } if fileShare.enable
    ] if storageAccount.enable
  ])
}

resource "azurerm_storage_account" "storage" {
  for_each = {
    for storageAccount in var.storageAccounts : storageAccount.name => storageAccount if storageAccount.enable
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
    for privateEndpoint in local.privateEndpoints : "${privateEndpoint.storageAccountName}-${privateEndpoint.type}" => privateEndpoint
  }
  name                = "${each.value.storageAccountName}-${each.value.type}"
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

resource "azurerm_role_assignment" "storage_contributor" {
  for_each = {
    for storageAccount in var.storageAccounts : storageAccount.name => storageAccount if storageAccount.enable
  }
  role_definition_name = "Contributor" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor
  principal_id         = data.azurerm_user_assigned_identity.studio.principal_id
  scope                = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${each.value.name}"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_role_assignment" "storage_blob_data_owner" {
  for_each = {
    for storageAccount in var.storageAccounts : storageAccount.name => storageAccount if storageAccount.enable
  }
  role_definition_name = "Storage Blob Data Owner" # https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-owner
  principal_id         = data.azurerm_client_config.studio.object_id
  scope                = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${each.value.name}"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_container" "core" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}-${blobContainer.name}" => blobContainer
  }
  name                 = each.value.name
  storage_account_name = each.value.storageAccountName
  depends_on = [
    azurerm_role_assignment.storage_blob_data_owner
  ]
}

resource "terraform_data" "blob_container_file_system_access_default" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}-${blobContainer.name}" => blobContainer if blobContainer.fileSystemEnable
  }
  provisioner "local-exec" {
    command = "az storage fs access update-recursive --auth-mode login --account-name ${each.value.storageAccountName} --file-system ${each.value.name} --path / --acl default:${each.value.fileSystemRootAcl}"
  }
  depends_on = [
    azurerm_storage_container.core
  ]
}

resource "terraform_data" "blob_container_file_system_access_pre_load" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}-${blobContainer.name}" => blobContainer if blobContainer.fileSystemEnable
  }
  provisioner "local-exec" {
    command = "az storage fs access update-recursive --auth-mode login --account-name ${each.value.storageAccountName} --file-system ${each.value.name} --path / --acl ${each.value.fileSystemRootAcl}"
  }
  depends_on = [
    azurerm_storage_container.core
  ]
}

resource "terraform_data" "blob_container_load_root" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}-${blobContainer.name}" => blobContainer if blobContainer.loadFiles && var.fileLoadSource.enable && var.fileLoadSource.blobName == ""
  }
  provisioner "local-exec" {
    environment = {
      AZURE_STORAGE_AUTH_MODE = "login"
    }
    command = "az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --recursive --account-name ${each.value.storageAccountName} --destination-container ${each.value.name}"
  }
  depends_on = [
    terraform_data.blob_container_file_system_access_default,
    terraform_data.blob_container_file_system_access_pre_load
  ]
}

resource "terraform_data" "blob_container_load_blob" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}-${blobContainer.name}" => blobContainer if blobContainer.loadFiles && var.fileLoadSource.enable && var.fileLoadSource.blobName != ""
  }
  provisioner "local-exec" {
    environment = {
      AZURE_STORAGE_AUTH_MODE = "login"
    }
    command = "az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --source-blob ${var.fileLoadSource.blobName} --recursive --account-name ${each.value.storageAccountName} --destination-container ${each.value.name} --destination-blob ${var.fileLoadSource.blobName}"
  }
  depends_on = [
    terraform_data.blob_container_file_system_access_default,
    terraform_data.blob_container_file_system_access_pre_load
  ]
}

resource "terraform_data" "blob_container_file_system_access_post_load" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}-${blobContainer.name}" => blobContainer if blobContainer.fileSystemEnable && blobContainer.loadFiles
  }
  provisioner "local-exec" {
    command = "az storage fs access update-recursive --auth-mode login --account-name ${each.value.storageAccountName} --file-system ${each.value.name} --path / --acl ${each.value.fileSystemRootAcl}"
  }
  depends_on = [
    azurerm_storage_container.core,
    terraform_data.blob_container_load_root,
    terraform_data.blob_container_load_blob
  ]
}

resource "azurerm_storage_share" "core" {
  for_each = {
    for fileShare in local.fileShares : "${fileShare.storageAccountName}-${fileShare.name}" => fileShare
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
    for fileShare in local.fileShares : "${fileShare.storageAccountName}-${fileShare.name}" => fileShare if fileShare.loadFiles && var.fileLoadSource.enable && var.fileLoadSource.blobName == ""
  }
  provisioner "local-exec" {
    environment = {
      AZURE_STORAGE_AUTH_MODE = "login"
    }
    command = "az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --recursive --account-name ${each.value.storageAccountName} --destination-share ${each.value.name}"
  }
  depends_on = [
    azurerm_storage_share.core
  ]
}

resource "terraform_data" "file_share_load_blob" {
  for_each = {
    for fileShare in local.fileShares : "${fileShare.storageAccountName}-${fileShare.name}" => fileShare if fileShare.loadFiles && var.fileLoadSource.enable && var.fileLoadSource.blobName != ""
  }
  provisioner "local-exec" {
    environment = {
      AZURE_STORAGE_AUTH_MODE = "login"
    }
    command = "az storage copy --source-account-name ${var.fileLoadSource.accountName} --source-account-key ${var.fileLoadSource.accountKey} --source-container ${var.fileLoadSource.containerName} --source-blob ${var.fileLoadSource.blobName} --recursive --account-name ${each.value.storageAccountName} --destination-share ${each.value.name} --destination-file-path ${var.fileLoadSource.blobName}"
  }
  depends_on = [
    azurerm_storage_share.core
  ]
}

output "blobStorageAccount" {
  value = local.blobStorageAccount
}
