// customize the simple VM by editing the following local variables
locals {
  // the region of the deployment
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  // nfs filer details
  storage_resource_group_name = "houdini_storage_rg"
  // more filer sizes listed at https://github.com/Azure/Avere/tree/main/src/terraform/modules/nfs_filer
  filer_size = "Standard_D2s_v3"

  // replace below variables with the infrastructure variables from 1.base_infrastructure
  location                       = ""
  vnet_cloud_cache_subnet_id     = ""
  vnet_cloud_cache_subnet_name   = ""
  vnet_cloud_filers_subnet_name  = ""
  vnet_jumpbox_subnet_id         = ""
  vnet_jumpbox_subnet_name       = ""
  vnet_name                      = ""
  vnet_render_clients1_subnet_id = ""
  vnet_resource_group            = ""
}

terraform {
  required_version = ">= 0.14.0"
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

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.storage_resource_group_name
  location = local.location
}

// the ephemeral filer
module "nasfiler1" {
  source              = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
  resource_group_name = azurerm_resource_group.nfsfiler.name
  location            = local.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data
  vm_size             = local.filer_size
  unique_name         = "nasfiler1"

  // network details
  virtual_network_resource_group = local.vnet_resource_group
  virtual_network_name           = local.vnet_name
  virtual_network_subnet_name    = local.vnet_cloud_filers_subnet_name

  depends_on = [
    azurerm_resource_group.nfsfiler,
  ]
}

output "filer_username" {
  value = module.nasfiler1.admin_username
}

output "filer_address" {
  value = module.nasfiler1.primary_ip
}

output "filer_export" {
  value = module.nasfiler1.core_filer_export
}

output "storage_resource_group_name" {
  value = local.storage_resource_group_name
}

output "use_nfs_storage" {
  value = true
}
