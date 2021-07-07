/*
* Create a Stock CentOS Image
*
*/

#### Versions
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.56.0"
    }
  }
  backend "azurerm" {
    key = "AppC.StockImage"
  }
}

provider "azurerm" {
  features {}
}

### Variables
variable "stock_image_rg" {
  type = string
}

variable "vm_admin_username" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "vm_size" {
  type = string
}

### Resources
data "azurerm_key_vault_secret" "virtualmachine" {
  name         = var.virtualmachine_key
  key_vault_id = var.key_vault_id
}

# https://www.terraform.io/docs/language/settings/backends/azurerm.html#data-source-configuration
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    key                  = "1.network"
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.container_name
  }
}

locals {
  unique_name = "vm"
  // VM details
  source_image_reference = local.source_image_reference_latest

  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = data.azurerm_key_vault_secret.virtualmachine.value
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = var.ssh_public_key == "" ? null : var.ssh_public_key

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

resource "azurerm_resource_group" "main" {
  name     = var.stock_image_rg
  location = var.location
}

data "azurerm_subnet" "subnet" {
  name                 = data.terraform_remote_state.network.outputs.render_subnet_name
  virtual_network_name = data.terraform_remote_state.network.outputs.vnet_name
  resource_group_name  = data.terraform_remote_state.network.outputs.network_rg
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
  size                  = var.vm_size

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
  admin_username                  = var.vm_admin_username
  admin_password                  = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? local.vm_admin_password : null
  disable_password_authentication = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? false : true
  dynamic "admin_ssh_key" {
    for_each = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? [] : [local.vm_ssh_key_data]
    content {
      username   = var.vm_admin_username
      public_key = local.vm_ssh_key_data
    }
  }
}

### Outputs
output "vm_admin_username" {
  value = var.vm_admin_username
}

output "ip_address" {
  value = azurerm_network_interface.main.ip_configuration[0].private_ip_address
}
