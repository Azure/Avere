terraform {
  required_version = ">= 1.2.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.19.1"
    }
  }
  backend "azurerm" {
    key = "3.storage"
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
              tier     = string
              sizeGiB  = number
              protocol = string
            }
          )
        )
      }
    )
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

variable "netAppAccounts" {
  type = list(
    object(
      {
        name = string
        capacityPools = list(
          object(
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
          )
        )
      }
    )
  )
}

variable "virtualNetwork" {
  type = object(
    {
      name                = string
      resourceGroupName   = string
      subnetNameStorage   = string
      subnetNameStorageHA = string
      subnetNameCache     = string
    }
  )
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
  count   = var.virtualNetwork.name != "" ? 0 : 1
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
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

data "azurerm_subnet" "storage_netapp" {
  name                 = var.virtualNetwork.name != "" ? var.virtualNetwork.subnetNameStorage : data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets[data.terraform_remote_state.network[0].outputs.virtualNetworkSubnetIndex.storageNetApp].name
  resource_group_name  = var.virtualNetwork.name != "" ? var.virtualNetwork.resourceGroupName : data.terraform_remote_state.network[0].outputs.resourceGroupName
  virtual_network_name = var.virtualNetwork.name != "" ? var.virtualNetwork.name : data.terraform_remote_state.network[0].outputs.virtualNetwork.name
}

data "azurerm_subnet" "storage_ha" {
  name                 = var.virtualNetwork.name != "" ? var.virtualNetwork.subnetNameStorageHA : data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets[data.terraform_remote_state.network[0].outputs.virtualNetworkSubnetIndex.storageHA].name
  resource_group_name  = var.virtualNetwork.name != "" ? var.virtualNetwork.resourceGroupName : data.terraform_remote_state.network[0].outputs.resourceGroupName
  virtual_network_name = var.virtualNetwork.name != "" ? var.virtualNetwork.name : data.terraform_remote_state.network[0].outputs.virtualNetwork.name
}

data "http" "current_host" {
  url = "https://api.ipify.org/?format=json"
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
        fileShareTier      = fileShare.tier
        fileShareSize      = fileShare.sizeGiB
        fileAccessProtocol = fileShare.protocol
        storageAccountName = storageAccount.name
      }
    ] if storageAccount.name != ""
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
            "@ANVILIP@/${reverse(split("/", data.azurerm_subnet.storage.address_prefixes[0]))[0]}"
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
          "@ANVILIP@/${reverse(split("/", data.azurerm_subnet.storage.address_prefixes[0]))[0]}"
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
  netAppCapacityPools = flatten([
    for netAppAccount in var.netAppAccounts : [
      for capacityPool in netAppAccount.capacityPools : {
        netAppAccountName = netAppAccount.name
        capacityPool      = capacityPool
      } if capacityPool.name != ""
    ] if netAppAccount.name != ""
  ])
  netAppVolumes = flatten([
    for netAppAccount in var.netAppAccounts : [
      for capacityPool in netAppAccount.capacityPools : [
        for volume in capacityPool.volumes : {
          netAppAccountName = netAppAccount.name
          capacityPoolName  = capacityPool.name
          volume            = volume
        } if volume.name != ""
      ] if capacityPool.name != ""
    ] if netAppAccount.name != ""
  ])
  hpcCachePrincipalId = "831d4223-7a3c-4121-a445-1e423591e57b"
}

resource "azurerm_resource_group" "storage" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

##################################################################################
# Storage (https://docs.microsoft.com/azure/storage/common/storage-introduction) #
##################################################################################

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
        jsondecode(data.http.current_host.body).ip
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

# https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor
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

# https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
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
    azurerm_private_endpoint.storage
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
  access_tier          = each.value.fileShareTier
  storage_account_name = each.value.storageAccountName
  enabled_protocol     = each.value.fileAccessProtocol
  quota                = each.value.fileShareSize
  depends_on = [
    azurerm_private_endpoint.storage
  ]
}

#############################################################################################################
# Hammerspace (https://azuremarketplace.microsoft.com/en-US/marketplace/apps/hammerspace.hammerspace_4_6_5) #
#############################################################################################################

resource "azurerm_availability_set" "storage_anvil" {
  count               = var.hammerspace.namePrefix != "" ? 1 : 0
  name                = "${var.hammerspace.namePrefix}Anvil"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
}

resource "azurerm_availability_set" "storage_dsx" {
  count               = var.hammerspace.namePrefix != "" ? 1 : 0
  name                = "${var.hammerspace.namePrefix}DSX"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
}

resource "azurerm_lb" "storage" {
  count               = var.hammerspace.namePrefix != "" ? 1 : 0
  name                = "${var.hammerspace.namePrefix}LB"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  sku                 = "Standard"
  frontend_ip_configuration {
    name      = "FrontendConfig"
    subnet_id = data.azurerm_subnet.storage.id
  }
}

resource "azurerm_lb_backend_address_pool" "storage" {
  count           = var.hammerspace.namePrefix != "" ? 1 : 0
  name            = "BackendPool"
  loadbalancer_id = azurerm_lb.storage[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "storage_anvil" {
  for_each = {
    for x in local.hammerspaceNodesAnvil : x.name => x
  }
  backend_address_pool_id = azurerm_lb_backend_address_pool.storage[0].id
  network_interface_id    = "${azurerm_resource_group.storage.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ip_configuration_name   = "ipConfig"
  depends_on = [
    azurerm_network_interface.storage_anvil
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

resource "azurerm_network_interface" "storage_anvil" {
  for_each = {
    for x in local.hammerspaceNodesAnvil : x.name => x
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.storage.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "storage_anvil_ha" {
  for_each = {
    for x in local.hammerspaceNodesAnvil : x.name => x
  }
  name                = "${each.value.name}HA"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.storage_ha.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "storage_anvil" {
  for_each = {
    for x in local.hammerspaceNodesAnvil : x.name => x
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.storage.name
  location                        = azurerm_resource_group.storage.location
  size                            = var.hammerspace.anvilNode.size
  admin_username                  = var.hammerspace.anvilNode.adminLogin.userName
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = var.hammerspace.anvilNode.adminLogin.disablePasswordAuth
  availability_set_id             = azurerm_availability_set.storage_anvil[0].id
  custom_data = base64encode(
    replace(replace(replace(jsonencode(local.hammerspaceCustomDataAnvil), "@ANVILIP@", azurerm_lb.storage[0].frontend_ip_configuration[0].private_ip_address), "@HA_MODE@", each.value.index == 0 ? "Primary" : "Secondary"), "@HOSTNAME@", each.value.name)
  )
  network_interface_ids = [
    "${azurerm_resource_group.storage.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}",
    "${azurerm_resource_group.storage.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}HA"
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
    azurerm_network_interface.storage_anvil,
    azurerm_network_interface.storage_anvil_ha
  ]
}

resource "azurerm_managed_disk" "storage_anvil" {
  for_each = {
    for x in local.hammerspaceNodesAnvil : x.name => x
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.storage.name
  location             = azurerm_resource_group.storage.location
  storage_account_type = each.value.dataDisk.storageType
  disk_size_gb         = each.value.dataDisk.sizeGB
  create_option        = "Empty"
}

resource "azurerm_virtual_machine_data_disk_attachment" "storage_anvil" {
  for_each = {
    for x in local.hammerspaceNodesAnvil : x.name => x
  }
  virtual_machine_id = "${azurerm_resource_group.storage.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  managed_disk_id    = "${azurerm_resource_group.storage.id}/providers/Microsoft.Compute/disks/${each.value.name}"
  caching            = each.value.dataDisk.cachingType
  lun                = each.value.index
  depends_on = [
    azurerm_linux_virtual_machine.storage_anvil,
    azurerm_managed_disk.storage_anvil
  ]
}

resource "azurerm_virtual_machine_extension" "storage_anvil" {
  for_each = {
    for x in local.hammerspaceNodesAnvil : x.name => x
  }
  name                       = "SetAdminPassword"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.storage.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  protected_settings = jsonencode({
    "commandToExecute": "ADMIN_PASSWORD='${data.azurerm_key_vault_secret.admin_password.value}' /usr/bin/hs-init-admin-pw"
  })
  depends_on = [
    azurerm_linux_virtual_machine.storage_anvil
  ]
}

resource "azurerm_network_interface" "storage_dsx" {
  for_each = {
    for x in local.hammerspaceNodesDsx : x.name => x
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.storage.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "storage_dsx" {
  for_each = {
    for x in local.hammerspaceNodesDsx : x.name => x
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.storage.name
  location                        = azurerm_resource_group.storage.location
  size                            = each.value.size
  admin_username                  = each.value.adminLogin.userName
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuth
  availability_set_id             = azurerm_availability_set.storage_dsx[0].id
  custom_data = base64encode(
    replace(replace(jsonencode(local.hammerspaceCustomDataDsx), "@ANVILIP@", azurerm_lb.storage[0].frontend_ip_configuration[0].private_ip_address), "@HOSTNAME@", each.value.name)
  )
  network_interface_ids = [
    "${azurerm_resource_group.storage.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
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
    for x in local.hammerspaceDisksDsx : x.name => x
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.storage.name
  location             = azurerm_resource_group.storage.location
  storage_account_type = each.value.dataDisk.storageType
  disk_size_gb         = each.value.dataDisk.sizeGB
  create_option        = "Empty"
}

resource "azurerm_virtual_machine_data_disk_attachment" "storage_dsx" {
  for_each = {
    for x in local.hammerspaceDisksDsx : x.name => x
  }
  virtual_machine_id = "${azurerm_resource_group.storage.id}/providers/Microsoft.Compute/virtualMachines/${each.value.machineName}"
  managed_disk_id    = "${azurerm_resource_group.storage.id}/providers/Microsoft.Compute/disks/${each.value.name}"
  caching            = each.value.dataDisk.cachingType
  lun                = each.value.index
  depends_on = [
    azurerm_linux_virtual_machine.storage_dsx,
    azurerm_managed_disk.storage_dsx
  ]
}

resource "azurerm_virtual_machine_extension" "storage_dsx" {
  for_each = {
    for x in local.hammerspaceNodesDsx : x.name => x
  }
  name                       = "SetAdminPassword"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.storage.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  protected_settings = jsonencode({
    "commandToExecute": "ADMIN_PASSWORD='${data.azurerm_key_vault_secret.admin_password.value}' /usr/bin/hs-init-admin-pw"
  })
  depends_on = [
    azurerm_linux_virtual_machine.storage_dsx
  ]
}

######################################################################################################
# NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) #
######################################################################################################

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
  size_in_tb          = each.value.capacityPool.sizeTiB
  service_level       = each.value.capacityPool.serviceLevel
  account_name        = each.value.netAppAccountName
  depends_on = [
    azurerm_netapp_account.storage
  ]
}

resource "azurerm_netapp_volume" "storage" {
  for_each = {
    for x in local.netAppVolumes : "${x.netAppAccountName}.${x.capacityPoolName}.${x.volume.name}" => x
  }
  name                = each.value.volume.name
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  storage_quota_in_gb = each.value.volume.sizeGiB
  service_level       = each.value.volume.serviceLevel
  volume_path         = each.value.volume.mountPath
  protocols           = each.value.volume.protocols
  pool_name           = each.value.capacityPoolName
  account_name        = each.value.netAppAccountName
  subnet_id           = data.azurerm_subnet.storage_netapp.id
  dynamic "export_policy_rule" {
    for_each = each.value.volume.exportPolicies 
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
