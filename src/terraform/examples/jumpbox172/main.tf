// customize the simple VM by adjusting the following local variables
locals {
  // the region of the deployment
  location          = "eastus"
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "PASSWORD"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
  ssh_port        = 22

  // network details
  vnet_name         = "rendervnet"
  jumpbox_static_ip = "192.168.3.254"

  // jumpbox details
  jumpbox_resource_group_name = "jumpbox_resource_group"
  // if you are running a locked down network, set jumpbox_add_public_ip to false
  jumpbox_add_public_ip = false
  // only build terraform provider if needed
  build_vfxt_terraform_provider = false
}

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "jumpboxrg" {
  name     = local.jumpbox_resource_group_name
  location = local.location
}

// the render network
module "network" {
  source                = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name   = local.jumpbox_resource_group_name
  create_resource_group = false
  vnet_name             = local.vnet_name
  location              = local.location

  vnet_address_space                    = "192.168.0.0/20"
  subnet_cloud_cache_address_prefix     = "192.168.1.0/24"
  subnet_cloud_filers_address_prefix    = "192.168.2.128/25"
  subnet_cloud_filers_ha_address_prefix = "192.168.2.0/25"
  subnet_jumpbox_address_prefix         = "192.168.3.0/24"
  subnet_render_clients1_address_prefix = "192.168.4.0/23"
  subnet_render_clients2_address_prefix = "192.168.6.0/23"

  depends_on = [
    resource.azurerm_resource_group.jumpboxrg
  ]
}

module "jumpbox" {
  source                        = "github.com/Azure/Avere/src/terraform/modules/jumpbox"
  resource_group_name           = azurerm_resource_group.jumpboxrg.name
  location                      = local.location
  admin_username                = local.vm_admin_username
  admin_password                = local.vm_admin_password
  ssh_key_data                  = local.vm_ssh_key_data
  add_public_ip                 = local.jumpbox_add_public_ip
  ssh_port                      = local.ssh_port
  build_vfxt_terraform_provider = local.build_vfxt_terraform_provider
  static_ip_address             = local.jumpbox_static_ip

  // network details
  virtual_network_resource_group = local.jumpbox_resource_group_name
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.jumpbox_subnet_name

  depends_on = [
    azurerm_resource_group.jumpboxrg,
    module.network,
  ]
}

output "jumpbox_username" {
  value = module.jumpbox.jumpbox_username
}

output "jumpbox_address" {
  value = module.jumpbox.jumpbox_address
}

output "ssh_command" {
  value = "ssh ${module.jumpbox.jumpbox_username}@${module.jumpbox.jumpbox_address}"
}
