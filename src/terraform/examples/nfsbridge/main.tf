// customize the simple VM by editing the following local variables
locals {
  // the region of the deployment
  location          = "westus2"
  resource_group    = "nfsbridge"
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
  ssh_port        = 22

  vm_size = "Standard_F32s_v2"

  // network details
  network_resource_group_name = "network_resource_group"
  vnet_name                   = "rendervnet"
  subnet_name                 = "cloud_filers"

  unique_name = "nfsbridge"
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

resource "azurerm_resource_group" "nfsbridge" {
  name     = local.resource_group
  location = local.location
}

module "nfsbridge" {
  source              = "github.com/Azure/Avere/src/terraform/modules/nfsbridge"
  resource_group_name = local.resource_group
  location            = local.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data
  ssh_port            = local.ssh_port
  vm_size             = local.vm_size

  // network details
  virtual_network_resource_group = local.network_resource_group_name
  virtual_network_name           = local.vnet_name
  virtual_network_subnet_name    = local.subnet_name

  depends_on = [
    azurerm_resource_group.nfsbridge,
  ]
}

output "address" {
  value = module.nfsbridge.address
}
