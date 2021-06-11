data "azurerm_key_vault" "keyvault" {
  name                = local.keyvault_name
  resource_group_name = local.keyvault_resource_group_name
}

data "azurerm_key_vault_secret" "virtualmachine" {
  name         = "virtualmachine"
  key_vault_id = data.azurerm_key_vault.keyvault.id
}

// customize the simple VM by editing the following local variables
locals {
  location                     = ""
  keyvault_name                = "renderkeyvault"
  keyvault_resource_group_name = "keyvault_rg"// customize the Secured VM by adjusting the following local variables

  // authentication details
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = data.azurerm_key_vault_secret.virtualmachine.value
  // leave ssh key data blank if you want to use a password
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  // VM details
  resource_group_name = "centosresource_group"
  unique_name         = "vm"
  vm_size             = "Standard_D2s_v3"

  // paste from 2.1.network/ outputs (re-run "terraform output" from that directory if needed)
  virtual_network_resource_group_name = "network_rg"
  virtual_network_name                = "vnet"
  virtual_network_subnet_name         = "rendernodes"

  source_image_reference = local.source_image_reference_latest

  source_image_reference_latest = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.7"
    version   = "latest"
  }

  source_image_reference_7_6 = {
    publisher = "OpenLogic"
    offer     = "CentOS-CI"
    sku       = "7-CI"
    version   = "7.6.20190426"
  }

  # even though it is deprecated, you can use the offer "CentOS-CI" for older Cent OS images
  source_image_reference_7_4 = {
    publisher = "OpenLogic"
    offer     = "CentOS-CI"
    sku       = "7-CI"
    version   = "7.4.20180417"
  }
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

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = local.location
}

data "azurerm_subnet" "subnet" {
  name                 = local.virtual_network_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.virtual_network_resource_group_name
}

resource "azurerm_network_interface" "main" {
  name                = "${local.unique_name}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                  = local.unique_name
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  network_interface_ids = [azurerm_network_interface.main.id]
  computer_name         = local.unique_name
  size                  = local.vm_size

  source_image_reference {
    publisher = local.source_image_reference.publisher
    offer     = local.source_image_reference.offer
    sku       = local.source_image_reference.sku
    version   = local.source_image_reference.version
  }

  // by default the OS has encryption at rest
  os_disk {
    name                 = "osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  // configuration for authentication.  If ssh key specified, ignore password
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

output "ip_address" {
  value = azurerm_network_interface.main.ip_configuration[0].private_ip_address
}

output "ssh_command" {
  value = "ssh ${local.vm_admin_username}@${azurerm_network_interface.main.ip_configuration[0].private_ip_address}"
}
