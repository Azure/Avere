// customize the HPC Cache by editing the following local variables
locals {
  // the region of the deployment
  location                      = "eastus"
  hpc_cache_resource_group_name = "vdbench_hpccache_rg"
  filer_resource_group_name     = "vdbench_filer_rg"
  network_resource_group_name   = "vdbench_network_rg"
  vmss_resource_group_name      = "vdbench_vmss_rg"

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
  usage_model = "WRITE_WORKLOAD_15"

  // nfs filer related variables
  nfs_export_path   = "/nfs1data"
  vm_admin_username = "azureuser"
  // the vdbench example requires an ssh key
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  // jumpbox variable
  jumpbox_add_public_ip = true
  ssh_port              = 22

  # download the latest vdbench from https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html
  # and upload to an azure storage blob and put the URL below
  vdbench_url = ""

  // vmss details
  unique_name  = "vmss"
  vm_count     = 12
  vmss_size    = "Standard_D2s_v3"
  mount_target = "/data"

  // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
  open_external_ports = [local.ssh_port, 3389]
  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  open_external_sources = ["*"]
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

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.location
}

// the render network
module "network" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_resource_group_name
  location            = local.location

  open_external_ports   = local.open_external_ports
  open_external_sources = local.open_external_sources
}

resource "azurerm_hpc_cache" "hpc_cache" {
  name                = local.cache_name
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  cache_size_in_gb    = local.cache_size
  subnet_id           = module.network.cloud_cache_subnet_id
  sku_name            = local.cache_throughput
}

// the ephemeral filer
module "nasfiler1" {
  source              = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
  resource_group_name = azurerm_resource_group.nfsfiler.name
  location            = azurerm_resource_group.nfsfiler.location
  admin_username      = local.vm_admin_username
  ssh_key_data        = local.vm_ssh_key_data
  vm_size             = "Standard_D32s_v3"
  unique_name         = "nasfiler1"

  // network details
  virtual_network_resource_group = local.network_resource_group_name
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.cloud_filers_subnet_name
}

resource "azurerm_hpc_cache_nfs_target" "nfs_targets" {
  name                = "nfs_targets"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  cache_name          = azurerm_hpc_cache.hpc_cache.name
  target_host_name    = module.nasfiler1.primary_ip
  usage_model         = local.usage_model
  namespace_junction {
    namespace_path = local.nfs_export_path
    nfs_export     = module.nasfiler1.core_filer_export
    target_path    = ""
  }
}

module "jumpbox" {
  source              = "github.com/Azure/Avere/src/terraform/modules/jumpbox"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  admin_username      = local.vm_admin_username
  ssh_key_data        = local.vm_ssh_key_data
  add_public_ip       = local.jumpbox_add_public_ip
  ssh_port            = local.ssh_port

  // network details
  virtual_network_resource_group = module.network.vnet_resource_group
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.jumpbox_subnet_name

  depends_on = [
    azurerm_resource_group.hpc_cache_rg,
  ]
}

// the vdbench module
module "vdbench_configure" {
  source = "github.com/Azure/Avere/src/terraform/modules/vdbench_config"

  node_address    = module.jumpbox.jumpbox_address
  admin_username  = module.jumpbox.jumpbox_username
  ssh_key_data    = local.vm_ssh_key_data
  ssh_port        = local.ssh_port
  nfs_address     = azurerm_hpc_cache.hpc_cache.mount_addresses[0]
  nfs_export_path = tolist(azurerm_hpc_cache_nfs_target.nfs_targets.namespace_junction)[0].namespace_path
  vdbench_url     = local.vdbench_url

  depends_on = [
    azurerm_hpc_cache_nfs_target.nfs_targets,
    module.jumpbox,
  ]
}

// the VMSS module
module "vmss" {
  source = "github.com/Azure/Avere/src/terraform/modules/vmss_mountable"

  resource_group_name            = local.vmss_resource_group_name
  location                       = local.location
  admin_username                 = local.vm_admin_username
  ssh_key_data                   = local.vm_ssh_key_data
  unique_name                    = local.unique_name
  vm_count                       = local.vm_count
  vm_size                        = local.vmss_size
  virtual_network_resource_group = module.network.vnet_resource_group
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.render_clients1_subnet_name
  mount_target                   = local.mount_target
  nfs_export_addresses           = azurerm_hpc_cache.hpc_cache.mount_addresses
  nfs_export_path                = local.nfs_export_path
  bootstrap_script_path          = module.vdbench_configure.bootstrap_script_path

  depends_on = [
    module.vdbench_configure,
  ]
}

output "jumpbox_username" {
  value = module.jumpbox.jumpbox_username
}

output "jumpbox_address" {
  value = module.jumpbox.jumpbox_address
}

output "mount_addresses" {
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
}

output "ssh_port" {
  value = local.ssh_port
}

output "export_namespace" {
  value = tolist(azurerm_hpc_cache_nfs_target.nfs_targets.namespace_junction)[0].namespace_path
}

output "vmss_id" {
  value = module.vmss.vmss_id
}

output "vmss_resource_group" {
  value = module.vmss.vmss_resource_group
}

output "vmss_name" {
  value = module.vmss.vmss_name
}

output "vmss_addresses_command" {
  // local-exec doesn't return output, and the only way to 
  // try to get the output is follow advice from https://stackoverflow.com/questions/49136537/obtain-ip-of-internal-load-balancer-in-app-service-environment/49436100#49436100
  // in the meantime just provide the az cli command to
  // the customer
  value = "az vmss nic list -g ${module.vmss.vmss_resource_group} --vmss-name ${module.vmss.vmss_name} --query \"[].ipConfigurations[].privateIpAddress\""
}
