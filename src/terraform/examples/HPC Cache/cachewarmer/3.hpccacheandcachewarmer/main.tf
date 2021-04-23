// customize the simple VM by editing the following local variables
locals {
  // the region of the deployment
  location = "eastus"

  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

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
  cache_name = "hpccache"

  // usage model
  //    WRITE_AROUND
  //    READ_HEAVY_INFREQ
  //    WRITE_WORKLOAD_15
  usage_model = "READ_HEAVY_INFREQ"

  // storage account hosting the queue
  storage_account_name = "storageaccount"
  queue_prefix_name    = "cachewarmer"

  // paste the values below from the output of setting up network and filer
  filer_address                        = ""
  filer_export                         = ""
  hpccache_cache_subnet_name           = ""
  hpccache_network_name                = ""
  hpccache_network_resource_group_name = ""
  hpccache_render_subnet_name          = ""

  // paste the values from the values from the jumpbox creation
  hpccache_resource_group_name = ""
  jumpbox_address              = ""
  jumpbox_username             = ""
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.12.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = local.hpccache_resource_group_name
  location                 = local.location
  account_kind             = "Storage" // set to storage v1 for cheapest cost on queue transactions
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_subnet" "vnet" {
  name                 = local.hpccache_cache_subnet_name
  virtual_network_name = local.hpccache_network_name
  resource_group_name  = local.hpccache_network_resource_group_name
}
resource "azurerm_hpc_cache" "hpc_cache" {
  name                = local.cache_name
  resource_group_name = local.hpccache_resource_group_name
  location            = local.location
  cache_size_in_gb    = local.cache_size
  sku_name            = local.cache_throughput
  subnet_id           = data.azurerm_subnet.vnet.id
}

resource "azurerm_hpc_cache_nfs_target" "nfs_targets" {
  name                = "nfs_targets"
  resource_group_name = local.hpccache_resource_group_name
  cache_name          = azurerm_hpc_cache.hpc_cache.name
  target_host_name    = local.filer_address
  usage_model         = local.usage_model
  namespace_junction {
    namespace_path = local.filer_export
    nfs_export     = local.filer_export
    target_path    = ""
  }
}

module "cachewarmer_build" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_build"

  // authentication with jumpbox
  node_address   = local.jumpbox_address
  admin_username = local.jumpbox_username
  admin_password = local.vm_admin_password
  ssh_key_data   = local.vm_ssh_key_data

  // bootstrap directory to store the cache manager binaries and install scripts
  bootstrap_mount_address = tolist(azurerm_hpc_cache.hpc_cache.mount_addresses)[0]
  bootstrap_export_path   = local.filer_export

  depends_on = [
    azurerm_hpc_cache.hpc_cache,
    azurerm_hpc_cache_nfs_target.nfs_targets,
  ]
}

module "cachewarmer_manager_install" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_manager_install"

  // authentication with jumpbox
  node_address   = local.jumpbox_address
  admin_username = local.jumpbox_username
  admin_password = local.vm_admin_password
  ssh_key_data   = local.vm_ssh_key_data

  // bootstrap directory to install the cache manager service
  bootstrap_mount_address       = module.cachewarmer_build.bootstrap_mount_address
  bootstrap_export_path         = module.cachewarmer_build.bootstrap_export_path
  bootstrap_manager_script_path = module.cachewarmer_build.cachewarmer_manager_bootstrap_script_path
  bootstrap_worker_script_path  = module.cachewarmer_build.cachewarmer_worker_bootstrap_script_path

  // the job path
  storage_account   = local.storage_account_name
  storage_key       = azurerm_storage_account.storage.primary_access_key
  queue_name_prefix = local.queue_prefix_name

  // the cachewarmer VMSS auth details
  vmss_user_name      = local.jumpbox_username
  vmss_password       = local.vm_admin_password
  vmss_ssh_public_key = local.vm_ssh_key_data
  vmss_subnet_name    = local.hpccache_render_subnet_name

  depends_on = [
    module.cachewarmer_build,
  ]
}

module "cachewarmer_submitjob" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_submitjob"

  // authentication with jumpbox
  node_address   = local.jumpbox_address
  admin_username = local.jumpbox_username
  admin_password = local.vm_admin_password
  ssh_key_data   = local.vm_ssh_key_data

  // the job path
  storage_account   = local.storage_account_name
  storage_key       = azurerm_storage_account.storage.primary_access_key
  queue_name_prefix = local.queue_prefix_name

  // the path to warm
  warm_mount_addresses    = join(",", tolist(azurerm_hpc_cache.hpc_cache.mount_addresses))
  warm_target_export_path = local.filer_export
  warm_target_path        = "/island"

  depends_on = [
    module.cachewarmer_manager_install,
  ]
}

output "bootstrap_mount_address" {
  value = module.cachewarmer_build.bootstrap_mount_address
}

output "bootstrap_export_path" {
  value = module.cachewarmer_build.bootstrap_export_path
}

output "cachewarmer_worker_bootstrap_script_path" {
  value = module.cachewarmer_build.cachewarmer_worker_bootstrap_script_path
}

output "cachewarmer_manager_bootstrap_script_path" {
  value = module.cachewarmer_build.cachewarmer_manager_bootstrap_script_path
}

output "jumpbox_username" {
  value = local.jumpbox_username
}

output "jumpbox_address" {
  value = local.jumpbox_address
}

output "mount_addresses" {
  value = tolist(azurerm_hpc_cache.hpc_cache.mount_addresses)
}
