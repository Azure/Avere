// customize the simple VM by editing the following local variables
locals {
    location4 = "australiaeast"
    
    // network details
    network_rg4_name = "${local.resource_group_unique_prefix}netregion4"

    // paste the below settings from the output of the 0.network/main.tf
    network-region1-vnet_id = ""
    network-region1-vnet_name = ""
    network-region2-vnet_id = ""
    network-region2-vnet_name = ""
    network-region3-vnet_id = ""
    network-region3-vnet_name = ""
    network_rg1_name = ""
    network_rg2_name = ""
    network_rg3_name = ""
    resource_group_unique_prefix = ""
    
    // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
    open_external_ports = [22,3389]
    // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
    // or if accessing from cloud shell, put "AzureCloud"
    open_external_sources = ["*"]
    dns_servers = null // set this to the dc, for example ["10.0.3.254"] could be use for domain controller
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

////////////////////////////////////////////////////////////////
// NETWORK
// 4. region 4 - 10.3.0.0/16
////////////////////////////////////////////////////////////////

// the render network
module "network-region4" {
    source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
    resource_group_name = local.network_rg4_name
    location            = local.location4
    dns_servers         = local.dns_servers

    open_external_ports                   = local.open_external_ports
    open_external_sources                 = local.open_external_sources
    vnet_address_space                    = "10.3.0.0/16"
    subnet_cloud_cache_address_prefix     = "10.3.1.0/24"
    subnet_cloud_filers_address_prefix    = "10.3.2.128/25"
    subnet_cloud_filers_ha_address_prefix = "10.3.2.0/25"
    subnet_jumpbox_address_prefix         = "10.3.3.0/24"
    subnet_render_clients1_address_prefix = "10.3.4.0/23"
    subnet_render_clients2_address_prefix = "10.3.6.0/23"
}

resource "azurerm_virtual_network_peering" "p1-4" {
  name                      = "peer1to4"
  resource_group_name       = local.network_rg1_name
  virtual_network_name      = local.network-region1-vnet_name
  remote_virtual_network_id = module.network-region4.vnet_id
}

resource "azurerm_virtual_network_peering" "p4-1" {
  name                      = "peer4to1"
  resource_group_name       = local.network_rg4_name
  virtual_network_name      = module.network-region4.vnet_name
  remote_virtual_network_id = local.network-region1-vnet_id
}

resource "azurerm_virtual_network_peering" "p2-4" {
  name                      = "peer2to4"
  resource_group_name       = local.network_rg2_name
  virtual_network_name      = local.network-region2-vnet_name
  remote_virtual_network_id = module.network-region4.vnet_id
}

resource "azurerm_virtual_network_peering" "p4-2" {
  name                      = "peer4to2"
  resource_group_name       = local.network_rg4_name
  virtual_network_name      = module.network-region4.vnet_name
  remote_virtual_network_id = local.network-region2-vnet_id
}

resource "azurerm_virtual_network_peering" "p3-4" {
  name                      = "peer3to4"
  resource_group_name       = local.network_rg3_name
  virtual_network_name      = local.network-region3-vnet_name
  remote_virtual_network_id = module.network-region4.vnet_id
}

resource "azurerm_virtual_network_peering" "p4-3" {
  name                      = "peer4to3"
  resource_group_name       = local.network_rg4_name
  virtual_network_name      = module.network-region4.vnet_name
  remote_virtual_network_id = local.network-region3-vnet_id
}

output "location4" {
  value = "\"${local.location4}\""
}

output "network_rg4_name" {
    value = "\"${local.network_rg4_name}\""
}

output "network-region4-cloud_filers_ha_subnet_name" {
  value = "\"${module.network-region4.cloud_filers_ha_subnet_name}\""
}

output "network-region4-cloud_filers_subnet_name" {
  value = "\"${module.network-region4.cloud_filers_subnet_name}\""
}

output "network-region4-vnet_name" {
  value = "\"${module.network-region4.vnet_name}\""
}

output "network-region4-vnet_id" {
  value = "\"${module.network-region4.vnet_id}\""
}

output "resource_group_unique_prefix" {
    value = "\"${local.resource_group_unique_prefix}\""
}