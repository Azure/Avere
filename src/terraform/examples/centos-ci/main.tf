// customize the Secured VM by adjusting the following local variables
locals {
  // the region of the deployment
  location          = "westus"
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "PASSWORD"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  resource_group_name = "centosresource_group"
  vm_size             = "Standard_D2s_v3"

  // network details
  virtual_network_resource_group = "network_resource_group"
  virtual_network_name           = "rendervnet"
  virtual_network_subnet_name    = "render_clients2"

  # load the files as b64
  foreman_file_b64 = base64gzip(replace(file("${path.module}/20-foreman.cfg"), "\r", ""))
  example_file_b64 = base64gzip(replace(file("${path.module}/examplefile.txt"), "\r", ""))

  # embed the files
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { foreman_file = local.foreman_file_b64, example_file_b64 = local.example_file_b64 })
}

terraform {
  required_version = ">= 0.14.0,< 0.16.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.56.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_subnet" "vnet" {
  name                 = local.virtual_network_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.virtual_network_resource_group
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_network_interface" "main" {
  name                = "nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                  = "vm"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  network_interface_ids = [azurerm_network_interface.main.id]
  computer_name         = "vm"
  size                  = local.vm_size

  # this encodes the payload
  custom_data = base64encode(local.cloud_init_file)

  // if needed replace source image reference with the id
  // source_image_id       = "some image id"
  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7_9"
    version   = "latest"
  }

  // by default the OS has encryption at rest
  os_disk {
    name                 = "osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  admin_username                  = local.vm_admin_username
  admin_password                  = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? local.vm_admin_password : null
  disable_password_authentication = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? false : true
  dynamic "admin_ssh_key" {
    for_each = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? [] : [local.vm_ssh_key_data]
    content {
      username   = local.vm_admin_username
      public_key = local.vm_ssh_key_data
    }
  }
}

output "username" {
  value = local.vm_admin_username
}

output "vm_address" {
  value = azurerm_network_interface.main.ip_configuration[0].private_ip_address
}

output "ssh_command" {
  value = "ssh ${local.vm_admin_username}@${azurerm_network_interface.main.ip_configuration[0].private_ip_address}"
}
