// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location = "westus2"
    
    // network details
    network_resource_group_name = "houdini_network_rg"

    // storage details
    storage_resource_group_name  = "houdini_storage_rg"
    storage_account_name         = "houdinistgacct"
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

// the render network
module "network" {
    source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
    resource_group_name = local.network_resource_group_name
    location            = local.location

    vnet_address_space                    = "10.0.0.0/16"
    subnet_cloud_cache_address_prefix     = "10.0.1.0/24"
    subnet_cloud_filers_address_prefix    = "10.0.2.0/24"
    subnet_jumpbox_address_prefix         = "10.0.3.0/24"
    subnet_render_clients1_address_prefix = "10.0.4.0/23"
    subnet_render_clients2_address_prefix = "10.0.6.0/23"
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

output "storage_resource_group_name" {
  value = "\"${local.storage_resource_group_name}\""
}

output "storage_account_name" {
  value = "\"${local.storage_account_name}\""
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

output "vnet_render_clients1_subnet_id" {
  value = "\"${module.network.render_clients1_subnet_id}\""
}