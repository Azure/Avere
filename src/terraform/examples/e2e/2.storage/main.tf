terraform {
  required_version = ">= 1.3.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.37.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~>0.9.1"
    }
  }
  backend "azurerm" {
    key = "2.storage"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

module "global" {
  source = "../0.global/module"
}

variable "resourceGroupName" {
  type = string
}

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
          name = string
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

variable "netAppAccount" {
  type = object(
    {
      name = string
      capacityPools = list(object(
        {
          name         = string
          sizeTiB      = number
          serviceLevel = string
          volumes = list(object(
            {
              name         = string
              sizeGiB      = number
              serviceLevel = string
              mountPath    = string
              protocols    = list(string)
              exportPolicies = list(object(
                {
                  ruleIndex      = number
                  readOnly       = bool
                  readWrite      = bool
                  rootAccess     = bool
                  protocols      = list(string)
                  allowedClients = list(string)
                }
              ))
            }
          ))
        }
      ))
    }
  )
}

variable "hammerspace" {
  type = object(
    {
      namePrefix = string
      domainName = string
      metadata = object(
        {
          machine = object(
            {
              namePrefix = string
              size       = string
              count      = number
            }
          )
          network = object(
            {
              enableAcceleratedNetworking = bool
            }
          )
          osDisk = object(
            {
              sizeGB      = number
              storageType = string
              cachingType = string
            }
          )
          dataDisk = object(
            {
              sizeGB      = number
              storageType = string
              cachingType = string
            }
          )
          adminLogin = object(
            {
              userName            = string
              userPassword        = string
              sshPublicKey        = string
              disablePasswordAuth = bool
            }
          )
        }
      )
      data = object(
        {
          machine = object(
            {
              namePrefix = string
              size       = string
              count      = number
            }
          )
          network = object(
            {
              enableAcceleratedNetworking = bool
            }
          )
          osDisk = object(
            {
              sizeGB      = number
              storageType = string
              cachingType = string
            }
          )
          dataDisk = object(
            {
              count       = number
              sizeGB      = number
              storageType = string
              cachingType = string
              enableRaid0 = bool
            }
          )
          adminLogin = object(
            {
              userName            = string
              userPassword        = string
              sshPublicKey        = string
              disablePasswordAuth = bool
            }
          )
        }
      )
      enableProximityPlacement   = bool
      enableMarketplaceAgreement = bool
    }
  )
}

variable "qumulo" {
  type = object(
    {
      name      = string
      planId    = string
      offerId   = string
      termId    = string
      autoRenew = bool
    }
  )
}

variable "storageNetwork" {
  type = object(
    {
      name                = string
      resourceGroupName   = string
      subnetNamePrimary   = string
      subnetNameSecondary = string
      serviceEndpointSubnets = list(object(
        {
          name               = string
          regionName         = string
          virtualNetworkName = string
        }
      ))
    }
  )
}

variable "managedIdentity" {
  type = object(
    {
      name              = string
      resourceGroupName = string
    }
  )
}

variable "keyVault" {
  type = object(
    {
      name                 = string
      resourceGroupName    = string
      keyNameAdminUsername = string
      keyNameAdminPassword = string
    }
  )
}

variable "monitorWorkspace" {
  type = object(
    {
      name              = string
      resourceGroupName = string
    }
  )
}

data "http" "client_address" {
  url = "https://api.ipify.org?format=json"
}

data "azurerm_user_assigned_identity" "render" {
  name                = var.managedIdentity.name != "" ? var.managedIdentity.name : module.global.managedIdentity.name
  resource_group_name = var.managedIdentity.resourceGroupName != "" ? var.managedIdentity.resourceGroupName : module.global.resourceGroupName
}

data "azurerm_key_vault" "render" {
  name                = var.keyVault.name != "" ? var.keyVault.name : module.global.keyVault.name
  resource_group_name = var.keyVault.resourceGroupName != "" ? var.keyVault.resourceGroupName : module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "admin_username" {
  name         = var.keyVault.keyNameAdminUsername != "" ? var.keyVault.keyNameAdminUsername : module.global.keyVault.secretName.adminUsername
  key_vault_id = data.azurerm_key_vault.render.id
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = var.keyVault.keyNameAdminPassword != "" ? var.keyVault.keyNameAdminPassword : module.global.keyVault.secretName.adminPassword
  key_vault_id = data.azurerm_key_vault.render.id
}

data "azurerm_log_analytics_workspace" "monitor" {
  name                = var.monitorWorkspace.name != "" ? var.monitorWorkspace.name : module.global.monitorWorkspace.name
  resource_group_name = var.monitorWorkspace.resourceGroupName != "" ? var.monitorWorkspace.resourceGroupName : module.global.resourceGroupName
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

data "azurerm_resource_group" "network" {
  name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.storageNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.storageNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_virtual_network" "storage" {
  count               = (!local.stateExistsNetwork && var.storageNetwork.name != "") || (local.stateExistsNetwork && data.terraform_remote_state.network.outputs.storageNetwork.name != "") ? 1 : 0
  name                = !local.stateExistsNetwork ? var.storageNetwork.name : data.terraform_remote_state.network.outputs.storageNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.storageNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "compute_storage" {
  name                 = !local.stateExistsNetwork ? var.storageNetwork.subnetNamePrimary : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.storage].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_subnet" "storage_primary" {
  count                = (!local.stateExistsNetwork && var.storageNetwork.name != "") || (local.stateExistsNetwork && data.terraform_remote_state.network.outputs.storageNetwork.name != "") ? 1 : 0
  name                 = !local.stateExistsNetwork ? var.storageNetwork.subnetNamePrimary : data.terraform_remote_state.network.outputs.storageNetwork.subnets[data.terraform_remote_state.network.outputs.storageNetwork.subnetIndex.primary].name
  resource_group_name  = data.azurerm_virtual_network.storage[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage[0].name
}

data "azurerm_subnet" "storage_secondary" {
  count                = (!local.stateExistsNetwork && var.storageNetwork.name != "") || (local.stateExistsNetwork && data.terraform_remote_state.network.outputs.storageNetwork.name != "") ? 1 : 0
  name                 = !local.stateExistsNetwork ? var.storageNetwork.subnetNameSecondary : data.terraform_remote_state.network.outputs.storageNetwork.subnets[data.terraform_remote_state.network.outputs.storageNetwork.subnetIndex.secondary].name
  resource_group_name  = data.azurerm_virtual_network.storage[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage[0].name
}

data "azurerm_subnet" "storage_netapp" {
  count                = (!local.stateExistsNetwork && var.storageNetwork.name != "") || (local.stateExistsNetwork && data.terraform_remote_state.network.outputs.storageNetwork.name != "") ? 1 : 0
  name                 = !local.stateExistsNetwork ? var.storageNetwork.subnetNamePrimary : data.terraform_remote_state.network.outputs.storageNetwork.subnets[data.terraform_remote_state.network.outputs.storageNetwork.subnetIndex.netAppFiles].name
  resource_group_name  = data.azurerm_virtual_network.storage[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage[0].name
}

locals {
  stateExistsNetwork     = try(length(data.terraform_remote_state.network.outputs) >= 0, false)
  serviceEndpointSubnets = !local.stateExistsNetwork ? var.storageNetwork.serviceEndpointSubnets : data.terraform_remote_state.network.outputs.storageEndpointSubnets
  blobContainers = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : {
        name               = blobContainer.name
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
  netAppVolumes = flatten([
    for capacityPool in var.netAppAccount.capacityPools : [
      for volume in capacityPool.volumes : merge(volume,
        {capacityPoolName = capacityPool.name}
      ) if volume.name != ""
    ] if capacityPool.name != "" && var.netAppAccount.name != ""
  ])
  hammerspaceImagePublisher = "hammerspace"
  hammerspaceImageProduct   = "hammerspace-4-6-5-byol"
  hammerspaceImageName      = "planformacc-byol"
  hammerspaceImageVersion   = "4.6.6"
  hammerspaceMetadataNodes = [
    for i in range(var.hammerspace.metadata.machine.count) : merge(var.hammerspace.metadata,
      { index = i },
      { name  = "${var.hammerspace.namePrefix}${var.hammerspace.metadata.machine.namePrefix}${i + 1}" }
    ) if var.hammerspace.namePrefix != ""
  ]
  hammerspaceDataNodes = [
    for i in range(var.hammerspace.data.machine.count) : merge(var.hammerspace.data,
      { index = i },
      { name  = "${var.hammerspace.namePrefix}${var.hammerspace.data.machine.namePrefix}${i + 1}" }
    ) if var.hammerspace.namePrefix != ""
  ]
  hammerspaceDataDisks = [
    for i in range(var.hammerspace.data.machine.count * var.hammerspace.data.dataDisk.count) : merge(var.hammerspace.data,
      { index       = i % var.hammerspace.data.dataDisk.count + 1 },
      { machineName = "${var.hammerspace.namePrefix}${var.hammerspace.data.machine.namePrefix}${floor(i / var.hammerspace.data.dataDisk.count) + 1}" },
      { name        = "${var.hammerspace.namePrefix}${var.hammerspace.data.machine.namePrefix}${floor(i / var.hammerspace.data.dataDisk.count) + 1}DataDisk${i % var.hammerspace.data.dataDisk.count + 1}" }
    ) if var.hammerspace.namePrefix != ""
  ]
  hammerspaceDomainName = var.hammerspace.domainName == "" ? "${var.hammerspace.namePrefix}.azure" : var.hammerspace.domainName
  hammerspaceMetadataNodeConfig = {
    "cluster": {
      "domainname": local.hammerspaceDomainName
    },
    "node": {
      "hostname": "@HOSTNAME@",
      "ha_mode": "Standalone"
    }
  }
  hammerspaceMetadataNodeConfigHA = {
    "cluster": {
      "domainname": local.hammerspaceDomainName
    },
    "node": {
      "hostname": "@HOSTNAME@",
      "ha_mode": "@HA_MODE@",
      "networks": {
        "eth0": {
          "cluster_ips": [
            "@METADATA_HOST_IP@/${reverse(split("/", try(data.azurerm_subnet.storage_primary[0].address_prefixes[0], data.azurerm_subnet.compute_storage.address_prefixes[0])))[0]}"
          ]
        },
        "eth1": {
          "dhcp": true
        }
      }
    }
  }
  hammerspaceDataNodeConfig = {
    "cluster": {
      "domainname": local.hammerspaceDomainName
      "metadata": {
        "ips": [
          "@METADATA_HOST_IP@/${reverse(split("/", try(data.azurerm_subnet.storage_primary[0].address_prefixes[0], data.azurerm_subnet.compute_storage.address_prefixes[0])))[0]}"
        ]
      }
    },
    "node": {
      "hostname": "@HOSTNAME@",
      "features": [
        "portal",
        "storage"
      ],
      "storage": {
        "options": var.hammerspace.data.dataDisk.enableRaid0 ? ["raid0"] : []
      }
      "add_volumes": true
    }
  }
  hammerspaceEnableHighAvailability = var.hammerspace.namePrefix != "" && var.hammerspace.metadata.machine.count > 1
}

###################################################################################
# Storage (https://learn.microsoft.com/azure/storage/common/storage-introduction) #
###################################################################################

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

#######################################################################################################
# NetApp Files (https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) #
#######################################################################################################

resource "azurerm_resource_group" "netapp_files" {
  count    = var.netAppAccount.name != "" ? 1 : 0
  name     = "${var.resourceGroupName}.NetAppFiles"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_netapp_account" "storage" {
  count               = var.netAppAccount.name != "" ? 1 : 0
  name                = var.netAppAccount.name
  resource_group_name = azurerm_resource_group.netapp_files[0].name
  location            = azurerm_resource_group.netapp_files[0].location
}

resource "azurerm_netapp_pool" "storage" {
  for_each = {
    for capacityPool in var.netAppAccount.capacityPools : capacityPool.name => capacityPool if var.netAppAccount.name != ""
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.netapp_files[0].name
  location            = azurerm_resource_group.netapp_files[0].location
  size_in_tb          = each.value.sizeTiB
  service_level       = each.value.serviceLevel
  account_name        = var.netAppAccount.name
  depends_on = [
    azurerm_netapp_account.storage
  ]
}

resource "azurerm_netapp_volume" "storage" {
  for_each = {
    for volume in local.netAppVolumes : "${volume.capacityPoolName}.${volume.name}" => volume
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.netapp_files[0].name
  location            = azurerm_resource_group.netapp_files[0].location
  storage_quota_in_gb = each.value.sizeGiB
  service_level       = each.value.serviceLevel
  volume_path         = each.value.mountPath
  protocols           = each.value.protocols
  pool_name           = each.value.capacityPoolName
  account_name        = var.netAppAccount.name
  subnet_id           = data.azurerm_subnet.storage_netapp[0].id
  dynamic export_policy_rule {
    for_each = each.value.exportPolicies
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

#######################################################################################################
# Hammerspace (https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5) #
#######################################################################################################

resource "azurerm_resource_group" "hammerspace" {
  count    = var.hammerspace.namePrefix != "" ? 1 : 0
  name     = "${var.resourceGroupName}.Hammerspace"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_proximity_placement_group" "storage" {
  count               = var.hammerspace.namePrefix != "" && var.hammerspace.enableProximityPlacement ? 1 : 0
  name                = var.hammerspace.namePrefix
  location            = azurerm_resource_group.hammerspace[0].location
  resource_group_name = azurerm_resource_group.hammerspace[0].name
}

resource "azurerm_availability_set" "storage_metadata" {
  count                        = var.hammerspace.namePrefix != "" ? 1 : 0
  name                         = "${var.hammerspace.namePrefix}${var.hammerspace.metadata.machine.namePrefix}"
  resource_group_name          = azurerm_resource_group.hammerspace[0].name
  location                     = azurerm_resource_group.hammerspace[0].location
  proximity_placement_group_id = var.hammerspace.enableProximityPlacement ? azurerm_proximity_placement_group.storage[0].id : null
}

resource "azurerm_availability_set" "storage_data" {
  count                        = var.hammerspace.namePrefix != "" ? 1 : 0
  name                         = "${var.hammerspace.namePrefix}${var.hammerspace.data.machine.namePrefix}"
  resource_group_name          = azurerm_resource_group.hammerspace[0].name
  location                     = azurerm_resource_group.hammerspace[0].location
  proximity_placement_group_id = var.hammerspace.enableProximityPlacement ? azurerm_proximity_placement_group.storage[0].id : null
}

resource "azurerm_network_interface" "storage_primary" {
  for_each = {
    for node in concat(local.hammerspaceMetadataNodes, local.hammerspaceDataNodes) : node.name => node
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = try(data.azurerm_subnet.storage_primary[0].id, data.azurerm_subnet.compute_storage.id)
    private_ip_address_allocation = "Dynamic"
  }
  enable_accelerated_networking = each.value.network.enableAcceleratedNetworking
}

resource "azurerm_network_interface" "storage_secondary" {
  for_each = {
    for metadataNode in local.hammerspaceMetadataNodes : metadataNode.name => metadataNode if local.hammerspaceEnableHighAvailability
  }
  name                = "${each.value.name}HA"
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = try(data.azurerm_subnet.storage_secondary[0].id, data.azurerm_subnet.compute_storage.id)
    private_ip_address_allocation = "Dynamic"
  }
  enable_accelerated_networking = each.value.network.enableAcceleratedNetworking
}

resource "azurerm_managed_disk" "storage" {
  for_each = {
    for machineDisk in concat(local.hammerspaceMetadataNodes, local.hammerspaceDataDisks) : machineDisk.name => machineDisk
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.hammerspace[0].name
  location             = azurerm_resource_group.hammerspace[0].location
  storage_account_type = each.value.dataDisk.storageType
  disk_size_gb         = each.value.dataDisk.sizeGB
  create_option        = "Empty"
}

resource "azurerm_marketplace_agreement" "hammerspace" {
  count     = var.hammerspace.namePrefix != "" && var.hammerspace.enableMarketplaceAgreement ? 1 : 0
  publisher = local.hammerspaceImagePublisher
  offer     = local.hammerspaceImageProduct
  plan      = local.hammerspaceImageName
}

resource "azurerm_linux_virtual_machine" "storage_metadata" {
  for_each = {
    for metadataNode in local.hammerspaceMetadataNodes : metadataNode.name => metadataNode
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.hammerspace[0].name
  location                        = azurerm_resource_group.hammerspace[0].location
  size                            = each.value.machine.size
  admin_username                  = each.value.adminLogin.userName != "" ? each.value.adminLogin.userName : data.azurerm_key_vault_secret.admin_username.value
  admin_password                  = each.value.adminLogin.userPassword != "" ? each.value.adminLogin.userPassword : data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuth
  availability_set_id             = azurerm_availability_set.storage_metadata[0].id
  proximity_placement_group_id    = var.hammerspace.enableProximityPlacement ? azurerm_proximity_placement_group.storage[0].id : null
  custom_data = base64encode(local.hammerspaceEnableHighAvailability ?
    replace(replace(replace(jsonencode(local.hammerspaceMetadataNodeConfigHA), "@METADATA_HOST_IP@", azurerm_lb.storage[0].frontend_ip_configuration[0].private_ip_address), "@HA_MODE@", each.value.index == 0 ? "Primary" : "Secondary"), "@HOSTNAME@", each.value.name) :
    replace(jsonencode(local.hammerspaceMetadataNodeConfig), "@HOSTNAME@", each.value.name)
  )
  network_interface_ids = distinct(local.hammerspaceEnableHighAvailability ? [
    "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}",
    "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}HA"
  ] : [
    "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}",
    "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ])
  os_disk {
    disk_size_gb         = var.hammerspace.metadata.osDisk.sizeGB
    storage_account_type = var.hammerspace.metadata.osDisk.storageType
    caching              = var.hammerspace.metadata.osDisk.cachingType
  }
  plan {
    publisher = local.hammerspaceImagePublisher
    product   = local.hammerspaceImageProduct
    name      = local.hammerspaceImageName
  }
  source_image_reference {
    publisher = local.hammerspaceImagePublisher
    offer     = local.hammerspaceImageProduct
    sku       = local.hammerspaceImageName
    version   = local.hammerspaceImageVersion
  }
  depends_on = [
    azurerm_marketplace_agreement.hammerspace,
    azurerm_network_interface.storage_primary,
    azurerm_network_interface.storage_secondary,
    azurerm_lb.storage
  ]
}

resource "azurerm_linux_virtual_machine" "storage_data" {
  for_each = {
    for dataNode in local.hammerspaceDataNodes : dataNode.name => dataNode
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.hammerspace[0].name
  location                        = azurerm_resource_group.hammerspace[0].location
  size                            = each.value.machine.size
  admin_username                  = each.value.adminLogin.userName != "" ? each.value.adminLogin.userName : data.azurerm_key_vault_secret.admin_username.value
  admin_password                  = each.value.adminLogin.userPassword != "" ? each.value.adminLogin.userPassword : data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuth
  availability_set_id             = azurerm_availability_set.storage_data[0].id
  proximity_placement_group_id    = var.hammerspace.enableProximityPlacement ? azurerm_proximity_placement_group.storage[0].id : null
  custom_data = base64encode(
    replace(replace(jsonencode(local.hammerspaceDataNodeConfig), "@METADATA_HOST_IP@", var.hammerspace.metadata.machine.count > 1 ? azurerm_lb.storage[0].frontend_ip_configuration[0].private_ip_address : azurerm_linux_virtual_machine.storage_metadata["${var.hammerspace.namePrefix}${var.hammerspace.metadata.machine.namePrefix}1"].private_ip_address), "@HOSTNAME@", each.value.name)
  )
  network_interface_ids = [
    "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    disk_size_gb         = each.value.osDisk.sizeGB
    storage_account_type = each.value.osDisk.storageType
    caching              = each.value.osDisk.cachingType
  }
  plan {
    publisher = local.hammerspaceImagePublisher
    product   = local.hammerspaceImageProduct
    name      = local.hammerspaceImageName
  }
  source_image_reference {
    publisher = local.hammerspaceImagePublisher
    offer     = local.hammerspaceImageProduct
    sku       = local.hammerspaceImageName
    version   = local.hammerspaceImageVersion
  }
  depends_on = [
    azurerm_marketplace_agreement.hammerspace,
    azurerm_linux_virtual_machine.storage_metadata,
    azurerm_network_interface.storage_primary,
    azurerm_lb.storage
  ]
}

resource "azurerm_virtual_machine_data_disk_attachment" "storage_metadata" {
  for_each = {
    for metadataDisk in local.hammerspaceMetadataNodes : metadataDisk.name => metadataDisk
  }
  virtual_machine_id = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  managed_disk_id    = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/disks/${each.value.name}"
  caching            = each.value.dataDisk.cachingType
  lun                = each.value.index
  depends_on = [
    azurerm_managed_disk.storage,
    azurerm_linux_virtual_machine.storage_metadata
  ]
}

resource "azurerm_virtual_machine_data_disk_attachment" "storage_data" {
  for_each = {
    for dataDisk in local.hammerspaceDataDisks : dataDisk.name => dataDisk
  }
  virtual_machine_id = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/virtualMachines/${each.value.machineName}"
  managed_disk_id    = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/disks/${each.value.name}"
  caching            = each.value.dataDisk.cachingType
  lun                = each.value.index
  depends_on = [
    azurerm_managed_disk.storage,
    azurerm_linux_virtual_machine.storage_data
  ]
}

resource "azurerm_virtual_machine_extension" "storage" {
  for_each = {
    for node in concat(local.hammerspaceMetadataNodes, local.hammerspaceDataNodes) : node.name => node
  }
  name                       = "Custom"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "script": "${base64encode(
      templatefile("initialize.sh", merge(
        { machineSize   = each.value.machine.size },
        { adminPassword = data.azurerm_key_vault_secret.admin_password.value }
      ))
    )}"
  })
  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.storage_metadata,
    azurerm_virtual_machine_data_disk_attachment.storage_data
  ]
}

resource "azurerm_lb" "storage" {
  count               = local.hammerspaceEnableHighAvailability ? 1 : 0
  name                = var.hammerspace.namePrefix
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
  sku                 = "Standard"
  frontend_ip_configuration {
    name      = "ipConfigFrontend"
    subnet_id = try(data.azurerm_subnet.storage_primary[0].id, data.azurerm_subnet.compute_storage.id)
  }
}

resource "azurerm_lb_backend_address_pool" "storage" {
  count           = local.hammerspaceEnableHighAvailability ? 1 : 0
  name            = "BackendPool"
  loadbalancer_id = azurerm_lb.storage[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "storage" {
  for_each = {
    for metadataNode in local.hammerspaceMetadataNodes : metadataNode.name => metadataNode if local.hammerspaceEnableHighAvailability
  }
  backend_address_pool_id = azurerm_lb_backend_address_pool.storage[0].id
  network_interface_id    = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ip_configuration_name   = "ipConfig"
  depends_on = [
    azurerm_network_interface.storage_primary
  ]
}

resource "azurerm_lb_rule" "storage" {
  count                          = local.hammerspaceEnableHighAvailability ? 1 : 0
  name                           = "Rule"
  loadbalancer_id                = azurerm_lb.storage[0].id
  frontend_ip_configuration_name = azurerm_lb.storage[0].frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.storage[0].id
  enable_floating_ip             = true
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.storage[0].id
  ]
}

resource "azurerm_lb_probe" "storage" {
  count           = local.hammerspaceEnableHighAvailability ? 1 : 0
  name            = "Probe"
  loadbalancer_id = azurerm_lb.storage[0].id
  protocol        = "Tcp"
  port            = 4505
}

resource "azurerm_resource_group_template_deployment" "admin" {
  count               = var.hammerspace.namePrefix != "" ? 1 : 0
  name                = "admin"
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  deployment_mode     = "Incremental"
  parameters_content  = jsonencode({
    "namePrefix" = {
      value = var.hammerspace.namePrefix
    },
    "adminPassword" = {
      value = data.azurerm_key_vault_secret.admin_password.value
    }
  })
  template_content = <<TEMPLATE
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "namePrefix": {
          "type": "string"
        },
        "adminPassword": {
          "type": "string"
        }
      },
      "variables": {
        "prefix": "[hsfunc.normalize(parameters('namePrefix'))]",
        "adminUsername": "[concat('user', uniqueString(variables('prefix')))]",
        "adminPassword": "[concat(uniqueString(variables('prefix')), 'Hh7!')]"
      },
      "functions": [
        {
          "namespace": "hsfunc",
          "members": {
            "normalize": {
              "parameters": [
                {
                  "name": "ins",
                  "type": "String"
                }
              ],
              "output": {
                "type": "String",
                "value": "[replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(parameters('ins'), '!', ''), '@', ''), '#', ''), '$', ''), '%', ''), '^', ''), '&', ''), '*', ''), '(', ''), ')', ''), '_', ''), '+', ''), '=', ''), ':', ''), ';', ''), '?', ''), '/', ''), '.', ''), '>', ''), ',', ''), '<', '')]"
              }
            }
          }
        }
      ],
      "resources": [
      ],
      "outputs": {
        "adminUsername": {
          "type": "string",
          "value": "[variables('adminUserName')]"
        },
        "adminPassword": {
          "type": "string",
          "value": "[variables('adminPassword')]"
        }
      }
    }
  TEMPLATE
}

####################################################################################################
# Qumulo (https://azuremarketplace.microsoft.com/marketplace/apps/qumulo1584033880660.qumulo-saas) #
####################################################################################################

resource "azurerm_resource_group" "qumulo" {
  count    = var.qumulo.name != "" ? 1 : 0
  name     = "${var.resourceGroupName}.Qumulo"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_resource_group_template_deployment" "qumulo" {
  count               = var.qumulo.name != "" ? 1 : 0
  name                = var.qumulo.name
  resource_group_name = azurerm_resource_group.qumulo[0].name
  deployment_mode     = "Incremental"
  parameters_content  = jsonencode({
    "name" = {
      value = var.qumulo.name
    },
    "planId" = {
      value = var.qumulo.planId
    },
    "offerId" = {
      value = var.qumulo.offerId
    },
    "termId" = {
      value = var.qumulo.termId
    },
    "autoRenew" = {
      value = var.qumulo.autoRenew
    }
  })
  template_content = <<TEMPLATE
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "name": {
          "type": "string"
        },
        "planId": {
          "type": "string"
        },
        "offerId": {
          "type": "string"
        },
        "termId": {
          "type": "string"
        },
        "autoRenew": {
          "type": "bool"
        }
      },
      "variables": {
      },
      "functions": [
      ],
      "resources": [
        {
          "type": "Microsoft.SaaS/resources",
          "name": "[parameters('name')]",
          "apiVersion": "2018-03-01-beta",
          "location": "global",
          "properties": {
            "publisherId": "qumulo1584033880660",
            "skuId": "[parameters('planId')]",
            "offerId": "[parameters('offerId')]",
            "termId": "[if(equals(parameters('termId'), 'Monthly'), 'gmz7xq9ge3py', 'o73usof6rkyy')]",
            "autoRenew": "[parameters('autoRenew')]",
            "paymentChannelType": "SubscriptionDelegated",
            "paymentChannelMetadata": {
              "AzureSubscriptionId": "[subscription().subscriptionId]"
            }
          }
        }
      ],
      "outputs": {
      }
    }
  TEMPLATE
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "resourceGroupNameNetAppFiles" {
  value = var.netAppAccount.name == "" ? "" : azurerm_resource_group.netapp_files[0].name
}

output "resourceGroupNameHammerspace" {
  value = var.hammerspace.namePrefix == "" ? "" : azurerm_resource_group.hammerspace[0].name
}

output "resourceGroupNameQumulo" {
  value = var.qumulo.name == "" ? "" : azurerm_resource_group.qumulo[0].name
}
