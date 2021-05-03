// customize the HPC Cache by editing the following local variables
locals {
  // the region of the deployment
  location = "eastus"

  // network details
  network_resource_group_name = "network_rg"
  virtual_network_name        = "vnet"
  cache_network_subnet_name   = "cache"

  // hpc cache details
  hpc_cache_resource_group_name = "hpc_cache_rg"

  // HPC Cache Throughput SKU - 3 allowed values for throughput (GB/s) of the cache
  //    Standard_2G
  //    Standard_4G
  //    Standard_8G
  cache_throughput = "Standard_2G"

  // HPC Cache Size - 5 allowed sizes (GBs) for the cache
  //     3072
  //     6144
  //    12288
  //    24576
  //    49152
  cache_size = 12288

  // unique name for cache
  cache_name = "uniquename"

  // usage model
  //    WRITE_AROUND
  //    READ_HEAVY_INFREQ
  //    WRITE_WORKLOAD_15
  usage_model = "READ_HEAVY_INFREQ"

  // nfs filer related variables
  filer_resource_group_name = "filer_resource_group"
  vm_admin_username         = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
}

terraform {
  required_version = ">= 0.14.0,< 0.16.0"
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

data "azurerm_subnet" "vnet" {
  name                 = local.cache_network_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.network_resource_group_name
}

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
}

resource "azurerm_hpc_cache" "hpc_cache" {
  name                = local.cache_name
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  cache_size_in_gb    = local.cache_size
  subnet_id           = data.vnet.id
  sku_name            = local.cache_throughput
}

resource "azurerm_hpc_cache_nfs_target" "nfs_targets" {
  name                = "nfs_targets"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  cache_name          = azurerm_hpc_cache.hpc_cache.name
  target_host_name    = "REPLACE_IP_ADDRESS"
  usage_model         = local.usage_model
  namespace_junction {
    namespace_path = "/nfs1data"
    nfs_export     = "/nfs1data"
    target_path    = ""
  }
}

output "mount_addresses" {
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
}

output "export_namespace" {
  value = tolist(azurerm_hpc_cache_nfs_target.nfs_targets.namespace_junction)[0].namespace_path
}
