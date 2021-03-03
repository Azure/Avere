data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

data "azurerm_resource_group" "nfsfiler" {
  name     = var.resource_group_name
  depends_on = [var.module_depends_on]
}

locals {
  # send the script file to custom data, adding env vars
  script_file_b64 = base64gzip(replace(file("${path.module}/installnfs.sh"),"\r",""))
  proxy_env = (var.proxy == null || var.proxy == "") ? "" : "http_proxy=${var.proxy} https_proxy=${var.proxy} no_proxy=169.254.169.254"
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { install_script = local.script_file_b64, export_path = var.nfs_export_path, export_options = var.nfs_export_options, proxy_env = local.proxy_env})
}

resource "azurerm_network_interface" "nfsfiler" {
  name                = "${var.unique_name}-nic"
  resource_group_name = data.azurerm_resource_group.nfsfiler.name
  location            = var.location

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = var.private_ip_address != null ? "Static" : "Dynamic"
    private_ip_address            = var.private_ip_address != null ? var.private_ip_address : null
  }
  
  depends_on = [var.module_depends_on]
}

resource "azurerm_linux_virtual_machine" "nfsfiler" {
  name = "${var.unique_name}-vm"
  location = var.location
  resource_group_name = data.azurerm_resource_group.nfsfiler.name
  network_interface_ids = [azurerm_network_interface.nfsfiler.id]
  computer_name  = var.unique_name
  custom_data = base64encode(local.cloud_init_file)
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
  
  depends_on = [var.module_depends_on]
}
