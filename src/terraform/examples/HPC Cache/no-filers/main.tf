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

// the render network
module "network" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_resource_group_name
  location            = local.location
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

output "mount_addresses" {
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
}
