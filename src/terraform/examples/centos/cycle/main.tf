// customize the simple VM by adjusting the following local variables
locals {
  resource_group_name = "cycle_rg"
  // paste in the id of the full custom image
  vm_size           = "Standard_D4s_v3"
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  # you can choose to use the marketplace image or a manual install
  # 1. true - marketplace image - https://docs.microsoft.com/en-us/azure/cyclecloud/qs-install-marketplace
  # 2. false - manual install - this installs on a centos image: https://docs.microsoft.com/en-us/azure/cyclecloud/how-to/install-manual
  use_marketplace_image = false

  // replace below variables with the infrastructure variables from 0.network
  location                 = ""
  vnet_jumpbox_subnet_name = ""
  vnet_name                = ""
  vnet_resource_group      = ""
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

resource "azurerm_resource_group" "vm" {
  name     = local.resource_group_name
  location = local.location
}

module "cyclecloud" {
  source              = "github.com/Azure/Avere/src/terraform/modules/cyclecloud"
  resource_group_name = azurerm_resource_group.vm.name
  location            = local.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data
  vm_size             = local.vm_size
  use_marketplace     = local.use_marketplace_image

  // network details
  virtual_network_resource_group = local.vnet_resource_group
  virtual_network_name           = local.vnet_name
  virtual_network_subnet_name    = local.vnet_jumpbox_subnet_name
}

output "nfs_username" {
  value = module.cyclecloud.admin_username
}

output "nfs_address" {
  value = module.cyclecloud.primary_ip
}

output "ssh_command" {
  value = "ssh ${module.cyclecloud.admin_username}@${module.cyclecloud.primary_ip}"
}
