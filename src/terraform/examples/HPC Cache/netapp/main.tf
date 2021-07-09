// customize the HPC Cache by editing the following local variables
locals {
  // the region of the deployment
  location = "eastus"

  // network details
  network_resource_group_name = "network_resource_group"

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
  usage_model = "READ_HEAVY_INFREQ"

  // netapp filer details
  netapp_resource_group_name = "netapp_resource_group"
  export_path                = "data"
  // possible values are Standard, Premium, Ultra
  service_level              = "Premium"
  pool_size_in_tb            = 4
  volume_storage_quota_in_gb = 100
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

// the render network
module "network" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_resource_group_name
  location            = local.location
}

resource "azurerm_subnet" "netapp" {
  name                 = "netapp-subnet"
  resource_group_name  = module.network.vnet_resource_group
  virtual_network_name = module.network.vnet_name
  address_prefixes     = ["10.0.255.0/24"]

  delegation {
    name = "netapp"

    service_delegation {
      name    = "Microsoft.Netapp/volumes"
      actions = ["Microsoft.Network/networkinterfaces/*", "Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  depends_on = [
    module.network,
  ]
}

resource "azurerm_resource_group" "netapprg" {
  name     = local.netapp_resource_group_name
  location = local.location
  // the depends on is necessary for destroy.  Due to the
  // limitation of the template deployment, the only
  // way to destroy template resources is to destroy
  // the resource group
  depends_on = [
    module.network,
  ]
}

resource "azurerm_netapp_account" "account" {
  name                = "netappaccount"
  location            = azurerm_resource_group.netapprg.location
  resource_group_name = azurerm_resource_group.netapprg.name
}

resource "azurerm_netapp_pool" "pool" {
  name                = "netapppool"
  location            = azurerm_resource_group.netapprg.location
  resource_group_name = azurerm_resource_group.netapprg.name
  account_name        = azurerm_netapp_account.account.name
  service_level       = local.service_level
  size_in_tb          = local.pool_size_in_tb
}

resource "azurerm_netapp_volume" "netappvolume" {
  name                = "netappvolume"
  location            = azurerm_resource_group.netapprg.location
  resource_group_name = azurerm_resource_group.netapprg.name
  account_name        = azurerm_netapp_account.account.name
  pool_name           = azurerm_netapp_pool.pool.name
  volume_path         = local.export_path
  service_level       = local.service_level
  subnet_id           = azurerm_subnet.netapp.id
  protocols           = ["NFSv3"]
  storage_quota_in_gb = local.volume_storage_quota_in_gb

  export_policy_rule {
    rule_index        = 1
    allowed_clients   = [module.network.vnet_address_space]
    protocols_enabled = ["NFSv3"]
    unix_read_write   = true
  }
}

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
  // the depends on is necessary for destroy.  Due to the
  // limitation of the template deployment, the only
  // way to destroy template resources is to destroy
  // the resource group
  depends_on = [
    module.network,
  ]
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
    namespace_path = "/datacache"
    nfs_export     = "/${local.export_path}"
    target_path    = ""
  }
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
