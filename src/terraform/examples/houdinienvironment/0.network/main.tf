// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location = "westus2"
    
    // network details
    network_resource_group_name = "houdini_network_rg"

    # advanced scenario: add external ports to work with cloud policies example [10022, 13389]
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
    source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
    resource_group_name = local.network_resource_group_name
    location            = local.location

    open_external_ports                   = local.open_external_ports
    vnet_address_space                    = "10.0.0.0/16"
    subnet_cloud_cache_address_prefix     = "10.0.1.0/24"
    subnet_cloud_filers_address_prefix    = "10.0.2.0/24"
    subnet_jumpbox_address_prefix         = "10.0.3.0/24"
    subnet_render_clients1_address_prefix = "10.0.4.0/23"
    subnet_render_clients2_address_prefix = "10.0.6.0/23"
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

output "vnet_render_clients1_subnet_id" {
  value = "\"${module.network.render_clients1_subnet_id}\""
}