locals {
  # create the A record lines
  last_octet = split(".", var.avere_first_ip_addr)[3]
  addr_prefix = trimsuffix(var.avere_first_ip_addr, ".${local.last_octet}")
  # technique from article: https://forum.netgate.com/topic/120486/round-robin-for-dns-forwarder-network-address/3
  local_a_records = [for i in range(var.avere_ip_addr_count): "local-data: \"${var.avere_filer_fqdn} A ${local.addr_prefix}.${local.last_octet + i}\""]
  local_a_records_str = "local-zone: \"${var.avere_filer_fqdn}\" transparent\n  ${join("\n  ", local.local_a_records)}"

  # create the dns forward lines  
  dns_servers = var.dns_server == null || var.dns_server == "" ? [] : split(" ", var.dns_server)
  forward_lines = [for s in local.dns_servers : "forward-addr: ${s}"]
  foward_lines_str = join("\n  ", local.forward_lines)

  # send the script file to custom data, adding env vars
  script_file_b64 = base64gzip(replace(file("${path.module}/install.sh"),"\r",""))
  unbound_conf_file_b64 = base64gzip(replace(templatefile("${path.module}/unbound.conf", { arecord_lines = local.local_a_records_str, forward_addr_lines = local.foward_lines_str }),"\r",""))
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { installcmd = local.script_file_b64, unboundconf = local.unbound_conf_file_b64, ssh_port = var.ssh_port })
}

data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group

  depends_on = [var.module_depends_on]
}

data "azurerm_subscription" "primary" {}

data "azurerm_resource_group" "vm" {
  name     = var.resource_group_name

  depends_on = [var.module_depends_on]
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.unique_name}-nic"
  resource_group_name = data.azurerm_resource_group.vm.name
  location            = var.location

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = var.private_ip_address != null ? "Static" : "Dynamic"
    private_ip_address            = var.private_ip_address != null ? var.private_ip_address : null
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name = "${var.unique_name}-vm"
  location = var.location
  resource_group_name = data.azurerm_resource_group.vm.name
  network_interface_ids = [azurerm_network_interface.vm.id]
  computer_name  = var.unique_name
  custom_data = base64encode(local.cloud_init_file)
  size = var.vm_size

  os_disk {
    name              = "${var.unique_name}-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS-CI"
    sku       = "7-CI"
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
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": " /bin/bash /opt/install.sh"
    }
SETTINGS
}

