#######################################################################################################
# Weka (https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform) #
#######################################################################################################

variable "weka" {
  type = object(
    {
      namePrefix = string
      machine = object(
        {
          size  = string
          count = number
        }
      )
      osDisk = object(
        {
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
}

resource "azurerm_resource_group" "weka" {
  count    = var.weka.namePrefix != "" ? 1 : 0
  name     = "${var.resourceGroupName}.Weka"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_network_interface" "storage_primary" {
  count               = var.weka.namePrefix != "" ? var.weka.machine.count : 0
  name                = "${var.weka.namePrefix}${count.index}"
  resource_group_name = azurerm_resource_group.weka[0].name
  location            = azurerm_resource_group.weka[0].location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = try(data.azurerm_subnet.storage_primary[0].id, data.azurerm_subnet.compute_storage.id)
    private_ip_address_allocation = "Dynamic"
  }
  #enable_accelerated_networking = each.value.network.enableAcceleratedNetworking
}

resource "azurerm_linux_virtual_machine" "weka" {
  count                           = var.weka.namePrefix != "" ? var.weka.machine.count : 0
  name                            = "${var.weka.namePrefix}${count.index}"
  resource_group_name             = azurerm_resource_group.weka[0].name
  location                        = azurerm_resource_group.weka[0].location
  size                            = var.weka.machine.size
  admin_username                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : var.weka.adminLogin.userName
  admin_password                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : var.weka.adminLogin.userPassword
  disable_password_authentication = var.weka.adminLogin.disablePasswordAuth
  network_interface_ids = [
    azurerm_network_interface.storage_primary[count.index].id
  ]
  os_disk {
    storage_account_type = var.weka.osDisk.storageType
    caching              = var.weka.osDisk.cachingType
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "Latest"
  }
  dynamic admin_ssh_key {
    for_each = var.weka.adminLogin.sshPublicKey == "" ? [] : [1]
    content {
      username   = var.weka.adminLogin.userName
      public_key = var.weka.adminLogin.sshPublicKey
    }
  }
}

resource "azurerm_virtual_machine_extension" "weka" {
  count                      = var.weka.namePrefix != "" ? var.weka.machine.count : 0
  name                       = "Custom"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.weka[0].id}/providers/Microsoft.Compute/virtualMachines/${var.weka.namePrefix}${count.index}"
  settings = jsonencode({
    "script": "${base64encode(
      templatefile("initialize.sh", merge(
        { machineSize = var.weka.machine.size }
      ))
    )}"
  })
  depends_on = [
    azurerm_linux_virtual_machine.weka
  ]
}
