locals {
  # deliver the vyos installation file via custom script
  script_file_b64 = base64gzip(replace(file("${path.module}/installvyos.sh"), "\r", ""))
  init_file       = templatefile("${path.module}/cloud-init.tpl", { installcmd = local.script_file_b64 })
}

data "azurerm_subnet" "vyossubnet" {
  name                 = var.vnet_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_rg
}

resource "azurerm_public_ip" "vyos" {
  name                = "${var.unique_name}publicip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"

  tags = var.tags
}

resource "azurerm_network_interface" "vyos" {
  name                = "${var.unique_name}nic"
  resource_group_name = var.resource_group_name
  location            = var.location
  # ip forwarding needed for vyos
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vyossubnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.static_private_ip
    public_ip_address_id          = azurerm_public_ip.vyos.id
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "vyos" {
  name                  = "${var.unique_name}vm"
  resource_group_name   = var.resource_group_name
  location              = var.location
  network_interface_ids = [azurerm_network_interface.vyos.id]
  computer_name         = "${var.unique_name}vm"
  custom_data           = base64encode(local.init_file)
  size                  = var.vm_size
  source_image_id       = var.vyos_image_id

  // by default the OS has encryption at rest
  os_disk {
    name                 = "${var.unique_name}osdisk"
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
