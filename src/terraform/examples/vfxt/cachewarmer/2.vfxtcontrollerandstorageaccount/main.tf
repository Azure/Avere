// customize the simple VM by editing the following local variables
locals {
  // the region of the deployment
  location = "eastus"
  vfxt_resource_group_name = "vfxt_resource_group"
  storage_resource_group_name = "storage_resource_group"
  
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  // controller details
  controller_add_public_ip = true
  
  // storage account details
  storage_account_name = "storageaccount"
  alternative_resource_groups = [local.storage_resource_group_name]
  
  // for ease paste all the values (even unused) from the output of setting up network and filer
  vfxt_cache_subnet_id = ""
  vfxt_cache_subnet_name = ""
  vfxt_jumpbox_subnet_id = ""
  vfxt_jumpbox_subnet_name = ""
  vfxt_network_name = ""
  vfxt_network_resource_group_name = ""
}

provider "azurerm" {
    version = "~>2.8.0"
    features {}
}

resource "azurerm_resource_group" "storage" {
  name     = local.storage_resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  network_rules {
      virtual_network_subnet_ids = [
          local.vfxt_cache_subnet_id,
          local.vfxt_jumpbox_subnet_id,
      ]
      default_action = "Deny"
  }
}

// the vfxt controller
module "vfxtcontroller" {
    source = "github.com/Azure/Avere/src/terraform/modules/controller"
    resource_group_name = local.vfxt_resource_group_name
    location = local.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.controller_add_public_ip
    alternative_resource_groups = local.alternative_resource_groups
    
    // network details
    virtual_network_resource_group = local.vfxt_network_resource_group_name
    virtual_network_name = local.vfxt_network_name
    virtual_network_subnet_name = local.vfxt_jumpbox_subnet_name
}

output "vfxt_resource_group_name" {
  value = "\"${local.vfxt_resource_group_name}\""
}

output "controller_username" {
  value = "\"${module.vfxtcontroller.controller_username}\""
}

output "controller_address" {
  value = "\"${module.vfxtcontroller.controller_address}\""
}

output "storage_account_name" {
  value = "\"${local.storage_account_name}\""
}