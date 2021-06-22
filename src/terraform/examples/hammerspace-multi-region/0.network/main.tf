// customize the simple VM by editing the following local variables
locals {
  // the region2 of the deployment
  location1 = "westus2"
  location2 = "westus"
  location3 = "canadaeast"

  resource_group_unique_prefix = ""

  // network details
  network_rg1_name = "${local.resource_group_unique_prefix}netregion1"
  network_rg2_name = "${local.resource_group_unique_prefix}netregion2"
  network_rg3_name = "${local.resource_group_unique_prefix}netregion3"

  # advanced scenario: add external ports to work with cloud policies example [10022, 13389]
  open_external_ports = [22, 3389]
  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  open_external_sources = ["*"]
  dns_servers           = null // set this to the dc, for example ["10.0.3.254"] could be use for domain controller
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

////////////////////////////////////////////////////////////////
// NETWORK
// 1. region 1 - 10.0.0.0/16
// 2. region 2 - 10.1.0.0/16
// 3. region 3 - 10.2.0.0/16
////////////////////////////////////////////////////////////////

// the render network
module "network-region1" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_rg1_name
  location            = local.location1
  dns_servers         = local.dns_servers

  open_external_ports                   = local.open_external_ports
  open_external_sources                 = local.open_external_sources
  vnet_address_space                    = "10.0.0.0/16"
  subnet_cloud_cache_address_prefix     = "10.0.1.0/24"
  subnet_cloud_filers_address_prefix    = "10.0.2.128/25"
  subnet_cloud_filers_ha_address_prefix = "10.0.2.0/25"
  subnet_jumpbox_address_prefix         = "10.0.3.0/24"
  subnet_render_clients1_address_prefix = "10.0.4.0/23"
  subnet_render_clients2_address_prefix = "10.0.6.0/23"
}

// the render network
module "network-region2" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_rg2_name
  location            = local.location2
  dns_servers         = local.dns_servers

  open_external_ports                   = local.open_external_ports
  open_external_sources                 = local.open_external_sources
  vnet_address_space                    = "10.1.0.0/16"
  subnet_cloud_cache_address_prefix     = "10.1.1.0/24"
  subnet_cloud_filers_address_prefix    = "10.1.2.128/25"
  subnet_cloud_filers_ha_address_prefix = "10.1.2.0/25"
  subnet_jumpbox_address_prefix         = "10.1.3.0/24"
  subnet_render_clients1_address_prefix = "10.1.4.0/23"
  subnet_render_clients2_address_prefix = "10.1.6.0/23"
}

// the render network
module "network-region3" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_rg3_name
  location            = local.location3
  dns_servers         = local.dns_servers

  open_external_ports                   = local.open_external_ports
  open_external_sources                 = local.open_external_sources
  vnet_address_space                    = "10.2.0.0/16"
  subnet_cloud_cache_address_prefix     = "10.2.1.0/24"
  subnet_cloud_filers_address_prefix    = "10.2.2.128/25"
  subnet_cloud_filers_ha_address_prefix = "10.2.2.0/25"
  subnet_jumpbox_address_prefix         = "10.2.3.0/24"
  subnet_render_clients1_address_prefix = "10.2.4.0/23"
  subnet_render_clients2_address_prefix = "10.2.6.0/23"
}

resource "azurerm_virtual_network_peering" "p1-2" {
  name                      = "peer1to2"
  resource_group_name       = local.network_rg1_name
  virtual_network_name      = module.network-region1.vnet_name
  remote_virtual_network_id = module.network-region2.vnet_id
}

resource "azurerm_virtual_network_peering" "p2-1" {
  name                      = "peer2to1"
  resource_group_name       = local.network_rg2_name
  virtual_network_name      = module.network-region2.vnet_name
  remote_virtual_network_id = module.network-region1.vnet_id
}

resource "azurerm_virtual_network_peering" "p1-3" {
  name                      = "peer1to3"
  resource_group_name       = local.network_rg1_name
  virtual_network_name      = module.network-region1.vnet_name
  remote_virtual_network_id = module.network-region3.vnet_id
}

resource "azurerm_virtual_network_peering" "p3-1" {
  name                      = "peer3to1"
  resource_group_name       = local.network_rg3_name
  virtual_network_name      = module.network-region3.vnet_name
  remote_virtual_network_id = module.network-region1.vnet_id
}

resource "azurerm_virtual_network_peering" "p2-3" {
  name                      = "peer2to3"
  resource_group_name       = local.network_rg2_name
  virtual_network_name      = module.network-region2.vnet_name
  remote_virtual_network_id = module.network-region3.vnet_id
}

resource "azurerm_virtual_network_peering" "p3-2" {
  name                      = "peer3to2"
  resource_group_name       = local.network_rg3_name
  virtual_network_name      = module.network-region3.vnet_name
  remote_virtual_network_id = module.network-region2.vnet_id
}

output "location1" {
  value = local.location1
}

output "location2" {
  value = local.location2
}

output "location3" {
  value = local.location3
}

output "resource_group_unique_prefix" {
  value = local.resource_group_unique_prefix
}

output "network_rg1_name" {
  value = local.network_rg1_name
}

output "network-region1-cloud_filers_ha_subnet_name" {
  value = module.network-region1.cloud_filers_ha_subnet_name
}

output "network-region1-cloud_filers_subnet_name" {
  value = module.network-region1.cloud_filers_subnet_name
}

output "network-region1-jumpbox_subnet_name" {
  value = module.network-region1.jumpbox_subnet_name
}

output "network-region1-cloud_cache_subnet_name" {
  value = module.network-region1.cloud_cache_subnet_name
}

output "network-region1-render_clients1_subnet_name" {
  value = module.network-region1.render_clients1_subnet_name
}

output "network-region1-vnet_name" {
  value = module.network-region1.vnet_name
}

output "network-region1-vnet_id" {
  value = module.network-region1.vnet_id
}

output "network_rg2_name" {
  value = local.network_rg2_name
}

output "network-region2-cloud_filers_ha_subnet_name" {
  value = module.network-region2.cloud_filers_ha_subnet_name
}

output "network-region2-cloud_filers_subnet_name" {
  value = module.network-region2.cloud_filers_subnet_name
}

output "network-region2-vnet_name" {
  value = module.network-region2.vnet_name
}

output "network-region2-vnet_id" {
  value = module.network-region2.vnet_id
}

output "network_rg3_name" {
  value = local.network_rg3_name
}

output "network-region3-cloud_filers_ha_subnet_name" {
  value = module.network-region3.cloud_filers_ha_subnet_name
}

output "network-region3-cloud_filers_subnet_name" {
  value = module.network-region3.cloud_filers_subnet_name
}

output "network-region3-vnet_name" {
  value = module.network-region3.vnet_name
}

output "network-region3-vnet_id" {
  value = module.network-region3.vnet_id
}

output "network-region1-jumpbox-subnet-id" {
  value = module.network-region1.jumpbox_subnet_id
}

