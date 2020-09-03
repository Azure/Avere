// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
    
    // network details
    network_resource_group_name = "network_resource_group"
    
    // nfs filer details
    filer_resource_group_name = "filer_resource_group"

    // storage details
    storage_resource_group_name = "storage_resource_group"
    storage_account_name = "storageaccount"
    avere_storage_container_name = "vfxt"

    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"

    // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
    open_external_ports = [22,3389]
    // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
    // or if accessing from cloud shell, put "AzureCloud"
    open_external_sources = ["*"]
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

// the render network
module "network" {
    source = "github.com/Azure/Avere/src/terraform/modules/render_network"
    resource_group_name = local.network_resource_group_name
    location = local.location

    open_external_ports   = local.open_external_ports
    open_external_sources = local.open_external_sources
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.location
}

module "nasfiler1" {
    source = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
    resource_group_name = azurerm_resource_group.nfsfiler.name
    location = azurerm_resource_group.nfsfiler.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    vm_size = "Standard_D2s_v3"
    unique_name = "nasfiler1"

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.cloud_filers_subnet_name
}

resource "azurerm_resource_group" "storage" {
  name     = local.storage_resource_group_name
  location = local.location
}

resource "azurerm_resource_group" "vfxt" {
  name     = local.vfxt_resource_group_name
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
          module.network.cloud_cache_subnet_id,
          // need for the controller to create the container
          module.network.jumpbox_subnet_id,
      ]
      default_action = "Deny"
  }
  // if the nsg associations do not complete before the storage account
  // create is started, it will fail with "subnet updating"
  depends_on = [module.network]
}

output "location" {
  value = "\"${local.location}\""
}

output "vnet_resource_group" {
  value = "\"${module.network.vnet_resource_group}\""
}

output "vnet_name" {
  value = "\"${module.network.vnet_name}\""
}

output "vnet_cloud_cache_subnet_name" {
  value = "\"${module.network.cloud_cache_subnet_name}\""
}

output "vnet_jumpbox_subnet_name" {
  value = "\"${module.network.jumpbox_subnet_name}\""
}

output "vnet_cloud_filers_subnet_name" {
  value = "\"${module.network.cloud_filers_subnet_name}\""
}

output "vnet_cloud_cache_subnet_id" {
  value = "\"${module.network.cloud_cache_subnet_id}\""
}

output "vnet_jumpbox_subnet_id" {
  value = "\"${module.network.jumpbox_subnet_id}\""
}

output "vnet_render_clients1_subnet_id" {
  value = "\"${module.network.render_clients1_subnet_id}\""
}

output "filer_resource_group_name" {
  value = "\"${local.filer_resource_group_name}\""
}

output "vfxt_resource_group_name" {
  value = "\"${local.vfxt_resource_group_name}\""
}

output "storage_resource_group_name" {
  value = "\"${local.storage_resource_group_name}\""
}

output "storage_account_name" {
  value = "\"${local.storage_account_name}\""
}

output "avere_storage_container_name" {
  value = "\"${local.avere_storage_container_name}\""
}