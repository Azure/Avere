locals {
  # deliver the wireguard installation file via custom script
  wg_script_file_b64 = base64gzip(replace(file("${path.module}/installwireguard.sh"), "\r", ""))
  wg_init_file       = templatefile("${path.module}/cloud-init.tpl", { installcmd = local.wg_script_file_b64 })
}

data "azurerm_subnet" "wireguardsubnet" {
  name                 = var.vnet_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_rg
}

resource "azurerm_public_ip" "wireguard" {
  name                = "${var.unique_name}wgpublicip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"

  tags = var.tags
}

resource "azurerm_network_interface" "wireguard" {
  name                = "${var.unique_name}wgnic"
  resource_group_name = var.resource_group_name
  location            = var.location
  # ip forwarding needed for wireguard
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.wireguardsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.wireguard.id
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "wireguard" {
  name                  = "${var.unique_name}wgvm"
  resource_group_name   = var.resource_group_name
  location              = var.location
  network_interface_ids = [azurerm_network_interface.wireguard.id]
  computer_name         = "${var.unique_name}wgvm"
  custom_data           = base64encode(local.wg_init_file)
  size                  = var.vm_size

  source_image_reference {
    // a 5.6 kernel is required at minimum: https://arstechnica.com/gadgets/2020/01/linus-torvalds-pulled-wireguard-vpn-into-the-5-6-kernel-source-tree/
    /*publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"*/

    // hirsute has the latest wireguard
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-hirsute"
    sku       = "21_04"
    version   = "latest"
  }

  // by default the OS has encryption at rest
  os_disk {
    name                 = "${var.unique_name}wgosdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  // configuration for authentication.  If ssh key specified, ignore password
  admin_username                  = var.admin_username
  admin_password                  = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_username != null && var.admin_username != "" ? var.admin_username : null
  disable_password_authentication = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_username != null && var.admin_username != "" ? false : true
  dynamic "admin_ssh_key" {
    for_each = var.ssh_key_data == null || var.ssh_key_data == "" ? [] : [var.ssh_key_data]
    content {
      username   = var.admin_username
      public_key = var.ssh_key_data
    }
  }

  tags = var.tags
}
