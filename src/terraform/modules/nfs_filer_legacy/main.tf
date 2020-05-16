data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

data "azurerm_resource_group" "nfsfiler" {
  name     = var.resource_group_name
}

locals {
  # send the script file to custom data, adding env vars
  script_file_b64 = base64gzip(replace(file("${path.module}/installnfs.sh"),"\r",""))
  proxy_env = (var.proxy == null || var.proxy == "") ? "" : "http_proxy=${var.proxy} https_proxy=${var.proxy} no_proxy=169.254.169.254"
}

resource "azurerm_network_interface" "nfsfiler" {
  name                = "${var.unique_name}-nic"
  resource_group_name = data.azurerm_resource_group.nfsfiler.name
  location            = data.azurerm_resource_group.nfsfiler.location

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "nfsfiler" {
  name = "${var.unique_name}-vm"
  location = data.azurerm_resource_group.nfsfiler.location
  resource_group_name = data.azurerm_resource_group.nfsfiler.name
  network_interface_ids = [azurerm_network_interface.nfsfiler.id]
  computer_name  = var.unique_name
  custom_data = local.script_file_b64
  size = var.vm_size
  
  os_disk {
    name              = "${var.unique_name}-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.7"
    version   = "latest"
  }

  admin_username = var.admin_username
  admin_password = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? var.admin_password : null
  disable_password_authentication = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? false : true
  dynamic "admin_ssh_key" {
      for_each = var.ssh_key_data == null || var.ssh_key_data == "" ? [] : [var.ssh_key_data]
      content {
          username   = var.admin_username
          public_key = var.ssh_key_data
      }
  }
}

resource "azurerm_virtual_machine_extension" "cse" {
  name = "${var.unique_name}-cse"
  virtual_machine_id   = azurerm_linux_virtual_machine.nfsfiler.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "/bin/base64 -d /var/lib/waagent/CustomData | /bin/gunzip | EXPORT_PATH=${var.nfs_export_path} EXPORT_OPTIONS=\"${var.nfs_export_options}\" ${local.proxy_env} /bin/bash 2>&1 | tee -a /var/log/installnfs.log ; exit 0"
    }
SETTINGS
}
