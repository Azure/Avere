// customize the simple VM by editing the following local variables
locals {
  // the region of the deployment
  location = "eastus"
  hpccache_resource_group_name = "hpccache_resource_group"
  
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  // controller details
  controller_add_public_ip = true
  
  // for ease paste all the values (even unused) from the output of setting up network and filer
  hpccache_jumpbox_subnet_name = ""
  hpccache_network_name = ""
  hpccache_network_resource_group_name = ""
}

provider "azurerm" {
    version = "~>2.8.0"
    features {}
}

resource "azurerm_resource_group" "jumpboxrg" {
  name     = local.hpccache_resource_group_name
  location = local.location
}
module "jumpbox" {
    source = "github.com/Azure/Avere/src/terraform/modules/jumpbox"
    resource_group_name = azurerm_resource_group.jumpboxrg.name
    location = azurerm_resource_group.jumpboxrg.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.controller_add_public_ip
    build_vfxt_terraform_provider = false
    
    // network details
    virtual_network_resource_group = local.hpccache_network_resource_group_name
    virtual_network_name = local.hpccache_network_name
    virtual_network_subnet_name = local.hpccache_jumpbox_subnet_name
}

output "hpccache_resource_group_name" {
  value = "\"${local.hpccache_resource_group_name}\""
}

output "jumpbox_username" {
  value = "\"${module.jumpbox.jumpbox_username}\""
}

output "jumpbox_address" {
  value = "\"${module.jumpbox.jumpbox_address}\""
}
