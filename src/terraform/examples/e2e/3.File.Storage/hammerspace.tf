#######################################################################################################
# Hammerspace (https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5) #
#######################################################################################################

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
              enableAcceleration = bool
            }
          )
          osDisk = object(
            {
              storageType = string
              cachingType = string
              sizeGB      = number
            }
          )
          dataDisk = object(
            {
              storageType = string
              cachingType = string
              sizeGB      = number
            }
          )
          adminLogin = object(
            {
              userName     = string
              userPassword = string
              sshPublicKey = string
              passwordAuth = object(
                {
                  disable = bool
                }
              )
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
              enableAcceleration = bool
            }
          )
          osDisk = object(
            {
              storageType = string
              cachingType = string
              sizeGB      = number
            }
          )
          dataDisk = object(
            {
              storageType = string
              cachingType = string
              enableRaid0 = bool
              sizeGB      = number
              count       = number
            }
          )
          adminLogin = object(
            {
              userName     = string
              userPassword = string
              sshPublicKey = string
              passwordAuth = object(
                {
                  disable = bool
                }
              )
            }
          )
        }
      )
    }
  )
}

locals {
  hammerspaceImage = {
    publisher = "hammerspace"
    product   = "hammerspace-4-6-5-byol"
    name      = "planformacc-byol-4_6_6"
    version   = "22.08.18"
  }
  hammerspaceMetadataNodes = [
    for i in range(var.hammerspace.metadata.machine.count) : merge(var.hammerspace.metadata, {
      index = i
      name  = "${var.hammerspace.namePrefix}${var.hammerspace.metadata.machine.namePrefix}${i + 1}"
    }) if var.hammerspace.namePrefix != ""
  ]
  hammerspaceDataNodes = [
    for i in range(var.hammerspace.data.machine.count) : merge(var.hammerspace.data, {
      index = i
      name  = "${var.hammerspace.namePrefix}${var.hammerspace.data.machine.namePrefix}${i + 1}"
    }) if var.hammerspace.namePrefix != ""
  ]
  hammerspaceDataDisks = [
    for i in range(var.hammerspace.data.machine.count * var.hammerspace.data.dataDisk.count) : merge(var.hammerspace.data, {
      index       = i % var.hammerspace.data.dataDisk.count + 1
      machineName = "${var.hammerspace.namePrefix}${var.hammerspace.data.machine.namePrefix}${floor(i / var.hammerspace.data.dataDisk.count) + 1}"
      name        = "${var.hammerspace.namePrefix}${var.hammerspace.data.machine.namePrefix}${floor(i / var.hammerspace.data.dataDisk.count) + 1}DataDisk${i % var.hammerspace.data.dataDisk.count + 1}"
    }) if var.hammerspace.namePrefix != ""
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
            "@METADATA_HOST_IP@/${reverse(split("/", local.storageSubnet.address_prefixes[0]))[0]}"
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
          "@METADATA_HOST_IP@/${reverse(split("/", local.storageSubnet.address_prefixes[0]))[0]}"
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

resource "azurerm_resource_group" "hammerspace" {
  count    = var.hammerspace.namePrefix != "" ? 1 : 0
  name     = "${var.resourceGroupName}.Hammerspace"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_proximity_placement_group" "storage" {
  count               = var.hammerspace.namePrefix != "" ? 1 : 0
  name                = var.hammerspace.namePrefix
  location            = azurerm_resource_group.hammerspace[0].location
  resource_group_name = azurerm_resource_group.hammerspace[0].name
}

resource "azurerm_availability_set" "storage_metadata" {
  count                        = var.hammerspace.namePrefix != "" ? 1 : 0
  name                         = "${var.hammerspace.namePrefix}${var.hammerspace.metadata.machine.namePrefix}"
  resource_group_name          = azurerm_resource_group.hammerspace[0].name
  location                     = azurerm_resource_group.hammerspace[0].location
  proximity_placement_group_id = azurerm_proximity_placement_group.storage[0].id
}

resource "azurerm_availability_set" "storage_data" {
  count                        = var.hammerspace.namePrefix != "" ? 1 : 0
  name                         = "${var.hammerspace.namePrefix}${var.hammerspace.data.machine.namePrefix}"
  resource_group_name          = azurerm_resource_group.hammerspace[0].name
  location                     = azurerm_resource_group.hammerspace[0].location
  proximity_placement_group_id = azurerm_proximity_placement_group.storage[0].id
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
    subnet_id                     = local.storageSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
  enable_accelerated_networking = each.value.network.enableAcceleration
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
    subnet_id                     = data.azurerm_subnet.storage_secondary[0].id
    private_ip_address_allocation = "Dynamic"
  }
  enable_accelerated_networking = each.value.network.enableAcceleration
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

resource "azurerm_linux_virtual_machine" "storage_metadata" {
  for_each = {
    for metadataNode in local.hammerspaceMetadataNodes : metadataNode.name => metadataNode
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.hammerspace[0].name
  location                        = azurerm_resource_group.hammerspace[0].location
  size                            = each.value.machine.size
  admin_username                  = module.global.keyVault.enable ? data.azurerm_key_vault_secret.admin_username[0].value : each.value.adminLogin.userName
  admin_password                  = module.global.keyVault.enable ? data.azurerm_key_vault_secret.admin_password[0].value : each.value.adminLogin.userPassword
  disable_password_authentication = each.value.adminLogin.passwordAuth.disable
  availability_set_id             = azurerm_availability_set.storage_metadata[0].id
  proximity_placement_group_id    = azurerm_proximity_placement_group.storage[0].id
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
    storage_account_type = var.hammerspace.metadata.osDisk.storageType
    caching              = var.hammerspace.metadata.osDisk.cachingType
    disk_size_gb         = var.hammerspace.metadata.osDisk.sizeGB
  }
  plan {
    publisher = local.hammerspaceImage.publisher
    product   = local.hammerspaceImage.product
    name      = local.hammerspaceImage.name
  }
  source_image_reference {
    publisher = local.hammerspaceImage.publisher
    offer     = local.hammerspaceImage.product
    sku       = local.hammerspaceImage.name
    version   = local.hammerspaceImage.version
  }
  depends_on = [
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
  admin_username                  = module.global.keyVault.enable ? data.azurerm_key_vault_secret.admin_username[0].value : each.value.adminLogin.userName
  admin_password                  = module.global.keyVault.enable ? data.azurerm_key_vault_secret.admin_password[0].value : each.value.adminLogin.userPassword
  disable_password_authentication = each.value.adminLogin.passwordAuth.disable
  availability_set_id             = azurerm_availability_set.storage_data[0].id
  proximity_placement_group_id    = azurerm_proximity_placement_group.storage[0].id
  custom_data = base64encode(
    replace(replace(jsonencode(local.hammerspaceDataNodeConfig), "@METADATA_HOST_IP@", var.hammerspace.metadata.machine.count > 1 ? azurerm_lb.storage[0].frontend_ip_configuration[0].private_ip_address : azurerm_linux_virtual_machine.storage_metadata["${var.hammerspace.namePrefix}${var.hammerspace.metadata.machine.namePrefix}1"].private_ip_address), "@HOSTNAME@", each.value.name)
  )
  network_interface_ids = [
    "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.osDisk.storageType
    caching              = each.value.osDisk.cachingType
    disk_size_gb         = each.value.osDisk.sizeGB
  }
  plan {
    publisher = local.hammerspaceImage.publisher
    product   = local.hammerspaceImage.product
    name      = local.hammerspaceImage.name
  }
  source_image_reference {
    publisher = local.hammerspaceImage.publisher
    offer     = local.hammerspaceImage.product
    sku       = local.hammerspaceImage.name
    version   = local.hammerspaceImage.version
  }
  depends_on = [
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

# resource "azurerm_virtual_machine_extension" "storage" {
#   for_each = {
#     for node in concat(local.hammerspaceMetadataNodes, local.hammerspaceDataNodes) : node.name => node
#   }
#   name                       = "Initialize"
#   type                       = "CustomScript"
#   publisher                  = "Microsoft.Azure.Extensions"
#   type_handler_version       = "2.1"
#   auto_upgrade_minor_version = true
#   virtual_machine_id         = "${azurerm_resource_group.hammerspace[0].id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
#   settings = jsonencode({
#     "script": "${base64encode(
#       templatefile("initialize.sh", {
#         adminPassword = module.global.keyVault.enable ? data.azurerm_key_vault_secret.admin_password[0].value : each.value.adminLogin.userPassword
#       })
#     )}"
#   })
#   depends_on = [
#     azurerm_virtual_machine_data_disk_attachment.storage_metadata,
#     azurerm_virtual_machine_data_disk_attachment.storage_data
#   ]
# }

resource "azurerm_lb" "storage" {
  count               = local.hammerspaceEnableHighAvailability ? 1 : 0
  name                = var.hammerspace.namePrefix
  resource_group_name = azurerm_resource_group.hammerspace[0].name
  location            = azurerm_resource_group.hammerspace[0].location
  sku                 = "Standard"
  frontend_ip_configuration {
    name      = "ipConfigFrontend"
    subnet_id = local.storageSubnet.id
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

output "resourceGroupNameHammerspace" {
  value = var.hammerspace.namePrefix != "" ? azurerm_resource_group.hammerspace[0].name : ""
}
