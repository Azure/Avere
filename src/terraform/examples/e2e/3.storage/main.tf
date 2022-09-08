terraform {
  required_version = ">= 1.2.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.21.1"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.28.1"
    }
  }
  backend "azurerm" {
    key = "3.storage"
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
  source = "../0.global"
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
      enableBlobNfsV3      = bool
      enableLargeFileShare = bool
      enableSecureTransfer = bool
      privateEndpointTypes = list(string)
      blobContainers = list(object(
        {
          name             = string
          accessType       = string
          localDirectories = list(string)
        }
      ))
      fileShares = list(object(
        {
          name     = string
          tier     = string
          sizeGiB  = number
          protocol = string
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
          volumes = list(
            object(
              {
                name         = string
                sizeGiB      = number
                serviceLevel = string
                mountPath    = string
                protocols    = list(string)
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
      ))
    }
  )
}

variable "hammerspace" {
  type = object(
    {
      namePrefix = string
      domainName = string
      anvilNode = object(
        {
          namePrefix = string
          size       = string
          count      = number
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
              sshPublicKey        = string
              disablePasswordAuth = bool
            }
          )
        }
      )
      dsxNode = object(
        {
          namePrefix = string
          size       = string
          count      = number
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
              enableRaid0 = bool
              storageType = string
              cachingType = string
            }
          )
          adminLogin = object(
            {
              userName            = string
              sshPublicKey        = string
              disablePasswordAuth = bool
            }
          )
        }
      )
    }
  )
}

variable "storageNetwork" {
  type = object(
    {
      name               = string
      resourceGroupName  = string
    }
  )
}

variable "storageEndpointSubnets" {
  type = list(object(
    {
      name               = string
      regionName         = string
      virtualNetworkName = string
    }
  ))
}

data "azurerm_key_vault" "vault" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = module.global.keyVaultSecretNameAdminPassword
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "terraform_remote_state" "network" {
  count   = local.useOverrideConfig ? 0 : 1
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
  }
}

data "azurerm_resource_group" "network" {
  name = data.azurerm_virtual_network.storage.resource_group_name
}

data "azurerm_virtual_network" "storage" {
  name                 = local.useOverrideConfig ? var.storageNetwork.name : data.terraform_remote_state.network[0].outputs.storageNetwork.name
  resource_group_name  = local.useOverrideConfig ? var.storageNetwork.resourceGroupName : data.terraform_remote_state.network[0].outputs.resourceGroupName
}

data "azurerm_subnet" "storage_primary" {
  name                 = local.useOverrideConfig ? var.storageNetwork.subnetNameStorage1 : data.terraform_remote_state.network[0].outputs.storageNetwork.subnets[data.terraform_remote_state.network[0].outputs.storageNetworkSubnetIndex.primary].name
  resource_group_name  = data.azurerm_virtual_network.storage.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage.name
}

data "azurerm_subnet" "storage_secondary" {
  name                 = local.useOverrideConfig ? var.storageNetwork.subnetNameStorage2 : data.terraform_remote_state.network[0].outputs.storageNetwork.subnets[data.terraform_remote_state.network[0].outputs.storageNetworkSubnetIndex.secondary].name
  resource_group_name  = data.azurerm_virtual_network.storage.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage.name
}

data "azurerm_subnet" "storage_netapp" {
  name                 = local.useOverrideConfig ? var.storageNetwork.subnetNameStorage1 : data.terraform_remote_state.network[0].outputs.storageNetwork.subnets[data.terraform_remote_state.network[0].outputs.storageNetworkSubnetIndex.netApp].name
  resource_group_name  = data.azurerm_virtual_network.storage.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage.name
}

data "azuread_service_principal" "hpc_cache" {
  display_name = "HPC Cache Resource Provider"
}

data "http" "current_host" {
  url = "https://api.ipify.org/?format=json"
}

locals {
  useOverrideConfig = var.storageNetwork.name != ""
  storageEndpointSubnets = local.useOverrideConfig ? var.storageEndpointSubnets : data.terraform_remote_state.network[0].outputs.storageEndpointSubnets
  privateDnsZones = distinct(flatten([
    for storageAccount in var.storageAccounts : [
      for privateEndpointType in storageAccount.privateEndpointTypes : {
        name = "privatelink.${privateEndpointType}.core.windows.net"
      }
    ] if storageAccount.name != ""
  ]))
  privateEndpoints = flatten([
    for storageAccount in var.storageAccounts : [
      for privateEndpointType in storageAccount.privateEndpointTypes : {
        type                = privateEndpointType
        privateDnsZoneName  = "privatelink.${privateEndpointType}.core.windows.net"
        storageAccountName  = storageAccount.name
        storageAccountId    = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${storageAccount.name}"
      }
    ] if storageAccount.name != ""
  ])
  blobContainers = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : {
        name               = blobContainer.name
        accessType         = blobContainer.accessType
        storageAccountName = storageAccount.name
      }
    ] if storageAccount.name != ""
  ])
  blobRootFiles = flatten([
    for storageAccount in var.storageAccounts : [
      for blobContainer in storageAccount.blobContainers : [
        for blob in fileset(blobContainer.name, "*") : {
          name               = blob
          containerName      = blobContainer.name
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
            name               = blob
            containerName      = blobContainer.name
            storageAccountName = storageAccount.name
          }
        ]
      ]
    ] if storageAccount.name != ""
  ])
  fileShares = flatten([
    for storageAccount in var.storageAccounts : [
      for fileShare in storageAccount.fileShares : {
        name               = fileShare.name
        tier               = fileShare.tier
        size               = fileShare.sizeGiB
        accessProtocol     = fileShare.protocol
        storageAccountName = storageAccount.name
      }
    ] if storageAccount.name != ""
  ])
  netAppVolumes = flatten([
    for capacityPool in var.netAppAccount.capacityPools : [
      for volume in capacityPool.volumes : merge(
        {capacityPoolName = capacityPool.name},
        volume
      ) if volume.name != ""
    ] if capacityPool.name != "" && var.netAppAccount.name != ""
  ])
  hammerspaceImagePublisher = "hammerspace"
  hammerspaceImageProduct   = "hammerspace-4-6-5-byol"
  hammerspaceImageName      = "planformacc-byol"
  hammerspaceImageVersion   = "latest"
  hammerspaceNodesAnvil = [
   for i in range(var.hammerspace.anvilNode.count) : merge({index = i}, {name = "${var.hammerspace.namePrefix}${var.hammerspace.anvilNode.namePrefix}${i + 1}"}, var.hammerspace.anvilNode) if var.hammerspace.namePrefix != ""
  ]
  hammerspaceNodesDsx = [
   for i in range(var.hammerspace.dsxNode.count) : merge({index = i}, {name = "${var.hammerspace.namePrefix}${var.hammerspace.dsxNode.namePrefix}${i + 1}"}, var.hammerspace.dsxNode) if var.hammerspace.namePrefix != ""
  ]
  hammerspaceDisksDsx = [
   for i in range(var.hammerspace.dsxNode.count * var.hammerspace.dsxNode.dataDisk.count) : merge({index = i % var.hammerspace.dsxNode.dataDisk.count + 1}, {machineName = "${var.hammerspace.namePrefix}${var.hammerspace.dsxNode.namePrefix}${floor(i / var.hammerspace.dsxNode.dataDisk.count) + 1}"}, {name = "${var.hammerspace.namePrefix}${var.hammerspace.dsxNode.namePrefix}${floor(i / var.hammerspace.dsxNode.dataDisk.count) + 1}DataDisk${i % var.hammerspace.dsxNode.dataDisk.count + 1}"}, var.hammerspace.dsxNode) if var.hammerspace.namePrefix != ""
  ]
  hammerspaceCustomDataAnvil = {
    "cluster": {
      "domainname": var.hammerspace.domainName == "" ? "${var.hammerspace.namePrefix}.azure" : var.hammerspace.domainName
    },
    "node": {
      "hostname": "@HOSTNAME@",
      "ha_mode": "@HA_MODE@",
      "networks": {
        "eth0": {
          "cluster_ips": [
            "@ANVILIP@/${reverse(split("/", data.azurerm_subnet.storage_primary.address_prefixes[0]))[0]}"
          ]
        },
        "eth1": {
          "dhcp": true
        }
      }
    }
  }
  hammerspaceCustomDataDsx = {
    "cluster": {
      "domainname": var.hammerspace.domainName == "" ? "${var.hammerspace.namePrefix}.azure" : var.hammerspace.domainName
      "metadata": {
        "ips": [
          "@ANVILIP@/${reverse(split("/", data.azurerm_subnet.storage_primary.address_prefixes[0]))[0]}"
        ]
      }
    },
    "node": {
      "features": [
        "portal",
        "storage"
      ],
      "add_volumes": true,
      "storage": {
        "options": var.hammerspace.dsxNode.dataDisk.enableRaid0 ? ["raid0"] : []
      },
      "hostname": "@HOSTNAME@"
    }
  }
}

##################################################################################
# Storage (https://docs.microsoft.com/azure/storage/common/storage-introduction) #
##################################################################################

resource "azurerm_resource_group" "storage" {
  name     = var.resourceGroupName
  location = data.azurerm_virtual_network.storage.location
}

resource "azurerm_storage_account" "storage" {
  for_each = {
    for storageAccount in var.storageAccounts : storageAccount.name => storageAccount if storageAccount.name != ""
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.storage.name
  location                        = azurerm_resource_group.storage.location
  account_kind                    = each.value.type
  account_tier                    = each.value.tier
  account_replication_type        = each.value.redundancy
  is_hns_enabled                  = each.value.enableBlobNfsV3
  nfsv3_enabled                   = each.value.enableBlobNfsV3
  large_file_share_enabled        = each.value.enableLargeFileShare ? true : null
  enable_https_traffic_only       = each.value.enableSecureTransfer
  allow_nested_items_to_be_public = false
  dynamic "network_rules" {
    for_each = each.value.enableBlobNfsV3 ? [1] : []
    content {
      default_action = "Deny"
      virtual_network_subnet_ids = [
        for storageEndpointSubnet in local.storageEndpointSubnets :
          "${data.azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${storageEndpointSubnet.virtualNetworkName}/subnets/${storageEndpointSubnet.name}"
      ]
      ip_rules = [
        jsondecode(data.http.current_host.response_body).ip
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each = {
    for privateDnsZone in local.privateDnsZones : privateDnsZone.name => privateDnsZone
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.storage.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "zone_links" {
  for_each = {
    for privateDnsZone in local.privateDnsZones : privateDnsZone.name => privateDnsZone
  }
  name                  = data.azurerm_virtual_network.storage.name
  resource_group_name   = azurerm_resource_group.storage.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = data.azurerm_virtual_network.storage.id
  depends_on = [
    azurerm_private_dns_zone.zones
  ]
}

resource "azurerm_private_endpoint" "storage" {
  for_each = {
    for privateEndpoint in local.privateEndpoints : "${privateEndpoint.storageAccountName}.${privateEndpoint.type}" => privateEndpoint
  }
  name                = "${each.value.storageAccountName}.${each.value.type}"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  subnet_id           = data.azurerm_subnet.storage_primary.id
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
      "${azurerm_resource_group.storage.id}/providers/Microsoft.Network/privateDnsZones/${each.value.privateDnsZoneName}"
    ]
  }
  depends_on = [
    azurerm_storage_account.storage,
    azurerm_private_dns_zone_virtual_network_link.zone_links
  ]
}

resource "azurerm_role_assignment" "storage_account_contributor" { # https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor
  for_each = {
    for storageAccount in var.storageAccounts : storageAccount.name => storageAccount if storageAccount.enableBlobNfsV3 && storageAccount.name != ""
  }
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azuread_service_principal.hpc_cache.object_id
  scope                = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${each.value.name}"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" { # https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  for_each = {
    for storageAccount in var.storageAccounts : storageAccount.name => storageAccount if storageAccount.enableBlobNfsV3 && storageAccount.name != ""
  }
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_service_principal.hpc_cache.object_id
  scope                = "${azurerm_resource_group.storage.id}/providers/Microsoft.Storage/storageAccounts/${each.value.name}"
  depends_on = [
    azurerm_storage_account.storage
  ]
}

resource "azurerm_storage_container" "containers" {
  for_each = {
    for blobContainer in local.blobContainers : "${blobContainer.storageAccountName}.${blobContainer.name}" => blobContainer
  }
  name                  = each.value.name
  container_access_type = each.value.accessType
  storage_account_name  = each.value.storageAccountName
  depends_on = [
    azurerm_private_endpoint.storage
  ]
}

resource "azurerm_storage_blob" "blobs" {
  for_each = {
    for blob in setunion(local.blobRootFiles, local.blobDirectoryFiles) : "${blob.storageAccountName}.${blob.name}" => blob
  }
  name                   = each.value.name
  storage_account_name   = each.value.storageAccountName
  storage_container_name = each.value.containerName
  source                 = "${path.cwd}/${each.value.containerName}/${each.value.name}"
  type                   = "Block"
  depends_on = [
    azurerm_storage_container.containers
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
  depends_on = [
    azurerm_private_endpoint.storage
  ]
}

######################################################################################################
# NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) #
######################################################################################################

resource "azurerm_resource_group" "netapp" {
  count    = var.netAppAccount.name != "" ? 1 : 0
  name     = "${var.resourceGroupName}.NetApp"
  location = data.azurerm_virtual_network.storage.location
}

resource "azurerm_netapp_account" "storage" {
  count               = var.netAppAccount.name != "" ? 1 : 0
  name                = var.netAppAccount.name
  resource_group_name = azurerm_resource_group.netapp[0].name
  location            = azurerm_resource_group.netapp[0].location
}

resource "azurerm_netapp_pool" "storage" {
  for_each = {
    for capacityPool in var.netAppAccount.capacityPools : capacityPool.name => capacityPool if var.netAppAccount.name != ""
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.netapp[0].name
  location            = azurerm_resource_group.netapp[0].location
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
  resource_group_name = azurerm_resource_group.netapp[0].name
  location            = azurerm_resource_group.netapp[0].location
  storage_quota_in_gb = each.value.sizeGiB
  service_level       = each.value.serviceLevel
  volume_path         = each.value.mountPath
  protocols           = each.value.protocols
  pool_name           = each.value.capacityPoolName
  account_name        = var.netAppAccount.name
  subnet_id           = data.azurerm_subnet.storage_netapp.id
  dynamic "export_policy_rule" {
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

#############################################################################################################
# Hammerspace (https://azuremarketplace.microsoft.com/en-US/marketplace/apps/hammerspace.hammerspace_4_6_5) #
#############################################################################################################

resource "azurerm_marketplace_agreement" "hammerspace" {
  count     = var.hammerspace.namePrefix != "" ? 1 : 0
  publisher = local.hammerspaceImagePublisher
  offer     = local.hammerspaceImageProduct
  plan      = local.hammerspaceImageName
}

resource "azurerm_resource_group" "hammerspace" {
  count    = var.hammerspace.namePrefix != "" ? 1 : 0
  name     = "${var.resourceGroupName}.Hammerspace"
  location = data.azurerm_virtual_network.storage.location
  depends_on = [
    azurerm_marketplace_agreement.hammerspace
  ]
}

resource "azurerm_availability_set" "storage_anvil" {
  count               = var.hammerspace.namePrefix != "" ? 1 : 0
  name                = "${var.hammerspace.namePrefix}Anvil"
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
}

resource "azurerm_availability_set" "storage_dsx" {
  count               = var.hammerspace.namePrefix != "" ? 1 : 0
  name                = "${var.hammerspace.namePrefix}DSX"
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
}

resource "azurerm_lb" "storage" {
  count               = var.hammerspace.namePrefix != "" ? 1 : 0
  name                = "${var.hammerspace.namePrefix}LB"
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
  sku                 = "Standard"
  frontend_ip_configuration {
    name      = "FrontendConfig"
    subnet_id = data.azurerm_subnet.storage_primary.id
  }
}

resource "azurerm_lb_backend_address_pool" "storage" {
  count           = var.hammerspace.namePrefix != "" ? 1 : 0
  name            = "BackendPool"
  loadbalancer_id = azurerm_lb.storage[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "storage_anvil" {
  for_each = {
    for anvilNode in local.hammerspaceNodesAnvil : anvilNode.name => anvilNode
  }
  backend_address_pool_id = azurerm_lb_backend_address_pool.storage[0].id
  network_interface_id    = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}_1"
  ip_configuration_name   = "ipConfig"
  depends_on = [
    azurerm_network_interface.storage_anvil_1
  ]
}

resource "azurerm_lb_rule" "storage" {
  count                          = var.hammerspace.namePrefix != "" ? 1 : 0
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
  count           = var.hammerspace.namePrefix != "" ? 1 : 0
  name            = "Probe"
  loadbalancer_id = azurerm_lb.storage[0].id
  protocol        = "Tcp"
  port            = 4505
}

resource "azurerm_network_interface" "storage_anvil_1" {
  for_each = {
    for anvilNode in local.hammerspaceNodesAnvil : anvilNode.name => anvilNode
  }
  name                = "${each.value.name}_1"
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.storage_primary.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "storage_anvil_2" {
  for_each = {
    for anvilNode in local.hammerspaceNodesAnvil : anvilNode.name => anvilNode
  }
  name                = "${each.value.name}_2"
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.storage_primary.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "storage_anvil" {
  for_each = {
    for anvilNode in local.hammerspaceNodesAnvil : anvilNode.name => anvilNode
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.hammerspace[0].name
  location                        = azurerm_resource_group.hammerspace[0].location
  size                            = var.hammerspace.anvilNode.size
  admin_username                  = var.hammerspace.anvilNode.adminLogin.userName
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = var.hammerspace.anvilNode.adminLogin.disablePasswordAuth
  availability_set_id             = azurerm_availability_set.storage_anvil[0].id
  custom_data = base64encode(
    replace(replace(replace(jsonencode(local.hammerspaceCustomDataAnvil), "@ANVILIP@", azurerm_lb.storage[0].frontend_ip_configuration[0].private_ip_address), "@HA_MODE@", each.value.index == 0 ? "Primary" : "Secondary"), "@HOSTNAME@", each.value.name)
  )
  network_interface_ids = [
    "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}_1",
    "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}_2"
  ]
  os_disk {
    disk_size_gb         = var.hammerspace.anvilNode.osDisk.sizeGB
    storage_account_type = var.hammerspace.anvilNode.osDisk.storageType
    caching              = var.hammerspace.anvilNode.osDisk.cachingType
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
    azurerm_network_interface.storage_anvil_1,
    azurerm_network_interface.storage_anvil_2
  ]
}

resource "azurerm_managed_disk" "storage_anvil" {
  for_each = {
    for anvilNode in local.hammerspaceNodesAnvil : anvilNode.name => anvilNode
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.hammerspace[0].name
  location             = azurerm_resource_group.hammerspace[0].location
  storage_account_type = each.value.dataDisk.storageType
  disk_size_gb         = each.value.dataDisk.sizeGB
  create_option        = "Empty"
}

resource "azurerm_virtual_machine_data_disk_attachment" "storage_anvil" {
  for_each = {
    for anvilNode in local.hammerspaceNodesAnvil : anvilNode.name => anvilNode
  }
  virtual_machine_id = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  managed_disk_id    = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/disks/${each.value.name}"
  caching            = each.value.dataDisk.cachingType
  lun                = each.value.index
  depends_on = [
    azurerm_linux_virtual_machine.storage_anvil,
    azurerm_managed_disk.storage_anvil
  ]
}

resource "azurerm_virtual_machine_extension" "storage_anvil" {
  for_each = {
    for anvilNode in local.hammerspaceNodesAnvil : anvilNode.name => anvilNode
  }
  name                       = "SetAdminPassword"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  protected_settings = jsonencode({
    "commandToExecute": "ADMIN_PASSWORD='${data.azurerm_key_vault_secret.admin_password.value}' /usr/bin/hs-init-admin-pw"
  })
  depends_on = [
    azurerm_linux_virtual_machine.storage_anvil
  ]
}

resource "azurerm_network_interface" "storage_dsx" {
  for_each = {
    for dsxNode in local.hammerspaceNodesDsx : dsxNode.name => dsxNode
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.storage_primary.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "storage_dsx" {
  for_each = {
    for dsxNode in local.hammerspaceNodesDsx : dsxNode.name => dsxNode
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.hammerspace[0].name
  location                        = azurerm_resource_group.hammerspace[0].location
  size                            = each.value.size
  admin_username                  = each.value.adminLogin.userName
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuth
  availability_set_id             = azurerm_availability_set.storage_dsx[0].id
  custom_data = base64encode(
    replace(replace(jsonencode(local.hammerspaceCustomDataDsx), "@ANVILIP@", azurerm_lb.storage[0].frontend_ip_configuration[0].private_ip_address), "@HOSTNAME@", each.value.name)
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
    azurerm_network_interface.storage_dsx
  ]
}

resource "azurerm_managed_disk" "storage_dsx" {
  for_each = {
    for dsxDisk in local.hammerspaceDisksDsx : dsxDisk.name => dsxDisk
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.hammerspace[0].name
  location             = azurerm_resource_group.hammerspace[0].location
  storage_account_type = each.value.dataDisk.storageType
  disk_size_gb         = each.value.dataDisk.sizeGB
  create_option        = "Empty"
}

resource "azurerm_virtual_machine_data_disk_attachment" "storage_dsx" {
  for_each = {
    for dsxDisk in local.hammerspaceDisksDsx : dsxDisk.name => dsxDisk
  }
  virtual_machine_id = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/virtualMachines/${each.value.machineName}"
  managed_disk_id    = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/disks/${each.value.name}"
  caching            = each.value.dataDisk.cachingType
  lun                = each.value.index
  depends_on = [
    azurerm_linux_virtual_machine.storage_dsx,
    azurerm_managed_disk.storage_dsx
  ]
}

resource "azurerm_virtual_machine_extension" "storage_dsx" {
  for_each = {
    for dsxNode in local.hammerspaceNodesDsx : dsxNode.name => dsxNode
  }
  name                       = "SetAdminPassword"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  protected_settings = jsonencode({
    "commandToExecute": "ADMIN_PASSWORD='${data.azurerm_key_vault_secret.admin_password.value}' /usr/bin/hs-init-admin-pw"
  })
  depends_on = [
    azurerm_linux_virtual_machine.storage_dsx
  ]
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "storageAccounts" {
  value = var.storageAccounts
}
