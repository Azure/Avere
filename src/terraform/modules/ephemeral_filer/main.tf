provider "azurerm" {
    version = "~>1.43.0"
}

data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

locals {
  # send the script file to custom data, adding env vars
  script_file_b64 = base64gzip(replace(file("${path.module}/installnfs.sh"),"\r",""))
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { install_script = local.script_file_b64, export_path = var.nfs_export_path, export_options = var.nfs_export_options})
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_network_interface" "nfsfiler" {
  name                = "${var.unique_name}-nic"
  resource_group_name = azurerm_resource_group.nfsfiler.name
  location            = azurerm_resource_group.nfsfiler.location

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "nfsfiler" {
  name = "${var.unique_name}-vm"
  location = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name
  network_interface_ids = [azurerm_network_interface.nfsfiler.id]
  vm_size = var.vm_size
  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    # only 7-CI supports cloud-init https://docs.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init
    sku       = "7-CI"
    version   = "latest"
  }

  dynamic "os_profile" {
    for_each = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? [var.admin_password] : [null] 
    content {
      computer_name  = var.unique_name
      admin_username = var.admin_username
      admin_password = var.admin_password
      custom_data = local.cloud_init_file
    }
  }

  // dynamic block when password is specified
  dynamic "os_profile_linux_config" {
    for_each = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? [var.admin_password] : [] 
    content {
      disable_password_authentication = false
    }
  }

  // dynamic block when SSH key is specified
  dynamic "os_profile_linux_config" {
    for_each = var.ssh_key_data == null || var.ssh_key_data == "" ? [] : [var.ssh_key_data]
    content {
      disable_password_authentication = true
      ssh_keys {
        path     = "/home/${var.admin_username}/.ssh/authorized_keys"
        key_data = var.ssh_key_data
      }
    }
  }
}