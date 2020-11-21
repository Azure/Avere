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
  perf_diag_tools_str = var.deploy_diagnostic_tools ? " PERF_DIAG_TOOLS=true " : ""
  enable_root_login_str = var.enable_root_login && var.ssh_key_data != null && var.ssh_key_data != "" ? " ALLOW_ROOT_LOGIN=true " : ""
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { install_script = local.script_file_b64, export_path = var.nfs_export_path, proxy_env = local.proxy_env, perf_diag_tools_str = local.perf_diag_tools_str, enable_root_login_str = local.enable_root_login_str})
}

resource "azurerm_network_interface" "nfsfiler" {
  name                = "${var.unique_name}-nic"
  resource_group_name = data.azurerm_resource_group.nfsfiler.name
  location            = data.azurerm_resource_group.nfsfiler.location

  count = var.deploy_vm ? 1 : 0

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
  network_interface_ids = [azurerm_network_interface.nfsfiler[0].id]
  computer_name  = var.unique_name
  custom_data = base64encode(local.cloud_init_file)
  size = var.vm_size
  
  os_disk {
    name              = "${var.unique_name}-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
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

  count = var.deploy_vm ? 1 : 0
}

resource "azurerm_virtual_machine_data_disk_attachment" "nfsfiler" {
  managed_disk_id    = var.managed_disk_id
  virtual_machine_id = azurerm_linux_virtual_machine.nfsfiler[0].id
  lun                = "0"
  caching            = var.caching

  count = var.deploy_vm ? 1 : 0
}

resource "azurerm_virtual_machine_extension" "cse" {
  name = "${var.unique_name}-cse"
  virtual_machine_id   = azurerm_linux_virtual_machine.nfsfiler[0].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "set -x && while :; do if [ -f '/opt/installnfs.complete' ]; then break; fi; sleep 5; done && set +x"
    }
SETTINGS

  count = var.deploy_vm ? 1 : 0

  depends_on = [azurerm_virtual_machine_data_disk_attachment.nfsfiler[0]]
}