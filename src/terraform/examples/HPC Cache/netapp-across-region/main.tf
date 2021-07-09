// customize the simple VM by editing the following local variables
locals {
  // the region of the main deployment
  location                    = "eastus"
  network_resource_group_name = "network_resource_group"

  // netapp filer details
  filer_location            = "westus2"
  filer_resource_group_name = "filer_resource_group"
  netapp_account_name       = "netappaccount"
  export_path               = "data"
  // possible values are Standard, Premium, Ultra
  service_level              = "Premium"
  pool_size_in_tb            = 4
  volume_storage_quota_in_gb = 100

  // vnet to vnet settings
  vpngw_generation = "Generation1" // generation and sku defined in https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark
  vpngw_sku        = "VpnGw2"
  shared_key       = "5v2ty45bt171p53c5h4r3dk4y"

  // hpc cache details
  hpc_cache_resource_group_name = "hpc_cache_resource_group"

  // HPC Cache Throughput SKU - 3 allowed values for throughput (GB/s) of the cache
  //  Standard_2G
  //  Standard_4G
  //  Standard_8G
  cache_throughput = "Standard_2G"

  // HPC Cache Size - 5 allowed sizes (GBs) for the cache
  //   3072
  //   6144
  //  12288
  //  24576
  //  49152
  cache_size = 12288

  // unique name for cache
  cache_name = "uniquename"

  // usage model
  //  WRITE_AROUND
  //  READ_HEAVY_INFREQ
  //  WRITE_WORKLOAD_15
  usage_model = "WRITE_AROUND"
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

////////////////////////////////////////////////////////////////
// virtual network
////////////////////////////////////////////////////////////////

module "network" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_resource_group_name
  location            = local.location
}

resource "azurerm_subnet" "rendergwsubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = module.network.vnet_resource_group
  virtual_network_name = module.network.vnet_name
  address_prefixes     = ["10.0.0.0/24"]

  depends_on = [
    module.network,
  ]
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.filer_location
}

resource "azurerm_virtual_network" "filervnet" {
  name                = "filervnet"
  address_space       = ["192.168.0.0/22"]
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name
}

resource "azurerm_subnet" "filergwsubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.nfsfiler.name
  virtual_network_name = azurerm_virtual_network.filervnet.name
  address_prefixes     = ["192.168.0.0/24"]
}

////////////////////////////////////////////////////////////////
// netapp
////////////////////////////////////////////////////////////////

resource "azurerm_subnet" "netapp" {
  name                 = "netapp-subnet"
  resource_group_name  = azurerm_resource_group.nfsfiler.name
  virtual_network_name = azurerm_virtual_network.filervnet.name
  address_prefixes     = ["192.168.1.0/24"]

  delegation {
    name = "netapp"

    service_delegation {
      name    = "Microsoft.Netapp/volumes"
      actions = ["Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_netapp_account" "account" {
  name                = local.netapp_account_name
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name
}

resource "azurerm_netapp_pool" "pool" {
  name                = "netapppool"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name
  account_name        = azurerm_netapp_account.account.name
  service_level       = local.service_level
  size_in_tb          = local.pool_size_in_tb
}

resource "azurerm_netapp_volume" "netappvolume" {
  name                = "netappvolume"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name
  account_name        = azurerm_netapp_account.account.name
  pool_name           = azurerm_netapp_pool.pool.name
  volume_path         = local.export_path
  service_level       = local.service_level
  subnet_id           = azurerm_subnet.netapp.id
  protocols           = ["NFSv3"]
  storage_quota_in_gb = local.volume_storage_quota_in_gb

  export_policy_rule {
    rule_index        = 1
    allowed_clients   = ["0.0.0.0/0"]
    protocols_enabled = ["NFSv3"]
    unix_read_write   = true
  }
}

////////////////////////////////////////////////////////////////
// Per documents NETAPP does not 
// work with vnet peering so we must
// create a VNET to VNET GW described here https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal
////////////////////////////////////////////////////////////////

resource "azurerm_public_ip" "filergwpublicip" {
  name                = "filergwpublicip"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "filervpngw" {
  name                = "filervpngw"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = local.vpngw_generation
  sku        = local.vpngw_sku

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.filergwpublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.filergwsubnet.id
  }
}

resource "azurerm_public_ip" "rendergwpublicip" {
  name                = "rendergwpublicip"
  location            = local.location
  resource_group_name = module.network.vnet_resource_group

  allocation_method = "Dynamic"

  depends_on = [
    module.network,
  ]
}

resource "azurerm_virtual_network_gateway" "rendervpngw" {
  name                = "rendervpngw"
  location            = local.location
  resource_group_name = module.network.vnet_resource_group

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = local.vpngw_generation
  sku        = local.vpngw_sku

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.rendergwpublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.rendergwsubnet.id
  }

  depends_on = [
    azurerm_subnet.filergwsubnet,
    azurerm_subnet.netapp,
  ]
}

resource "azurerm_virtual_network_gateway_connection" "filer_to_render" {
  name                = "filer_to_render"
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.filervpngw.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.rendervpngw.id

  shared_key = local.shared_key
}

resource "azurerm_virtual_network_gateway_connection" "render_to_filer" {
  name                = "render_to_filer"
  location            = local.location
  resource_group_name = module.network.vnet_resource_group

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.rendervpngw.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.filervpngw.id

  shared_key = local.shared_key
}

////////////////////////////////////////////////////////////////
// HPC Cache
////////////////////////////////////////////////////////////////

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
}

resource "azurerm_hpc_cache" "hpc_cache" {
  name                = local.cache_name
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  cache_size_in_gb    = local.cache_size
  subnet_id           = module.network.cloud_cache_subnet_id
  sku_name            = local.cache_throughput
}

resource "azurerm_hpc_cache_nfs_target" "nfs_targets" {
  name                = "nfs_targets"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  cache_name          = azurerm_hpc_cache.hpc_cache.name
  target_host_name    = azurerm_netapp_volume.netappvolume.mount_ip_addresses[0]
  usage_model         = local.usage_model
  namespace_junction {
    namespace_path = "/data"
    nfs_export     = "/${local.export_path}"
    target_path    = ""
  }

  depends_on = [
    azurerm_virtual_network_gateway_connection.render_to_filer,
    azurerm_virtual_network_gateway_connection.filer_to_render,
  ]
}

output "netapp_addresses" {
  value = azurerm_netapp_volume.netappvolume.mount_ip_addresses
}

output "netapp_export" {
  value = "/${local.export_path}"
}

output "hpccache_mount_addresses" {
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
}

output "hpccache_export_namespace" {
  value = tolist(azurerm_hpc_cache_nfs_target.nfs_targets.namespace_junction)[0].namespace_path
}
