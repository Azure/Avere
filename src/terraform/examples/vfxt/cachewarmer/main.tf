# versions
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
    avere = {
      source  = "hashicorp/avere"
      version = ">=1.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# variables
variable "cloud_location" {
  type = string
}

variable "cloud_rg" {
  type = string
}

variable "onprem_location" {
  type = string
}

variable "onprem_rg" {
  type = string
}

variable "filer_size" {
  type = string
}

variable "vm_admin_username" {
  type = string
}

variable "vm_admin_password" {
  type = string
}

variable "vm_ssh_key_data" {
  type = string
}

variable "ssh_port" {
  type = number
}

variable "controller_add_public_ip" {
  type = string
}

variable "controller_size" {
  type = string
}

variable "island_animation_sas_url" {
  type = string
}

variable "island_basepackage_sas_url" {
  type = string
}

variable "island_pbrt_sas_url" {
  type = string
}

variable "vfxt_cluster_name" {
  type = string
}

variable "vfxt_cluster_password" {
  type = string
}

variable "vfxt_use_test_sku" {
  type = bool
}

variable "cache_policy" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "queue_prefix_name" {
  type = string
}

# resources
locals {
  // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
  open_external_ports = [var.ssh_port, 3389]
  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  open_external_sources = ["*"]
  // set the vfxt ssh key to be same as controller
  vfxt_ssh_key_data = var.vm_ssh_key_data
}

////////////////////////////////////////////////////////////////
// the cloud network
////////////////////////////////////////////////////////////////
resource "azurerm_resource_group" "cloud" {
  name     = var.cloud_rg
  location = var.cloud_location
}

module "cloud_network" {
  create_resource_group = false
  source                = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name   = var.cloud_rg
  location              = var.cloud_location

  open_external_ports   = local.open_external_ports
  open_external_sources = local.open_external_sources

  depends_on = [
    azurerm_resource_group.cloud,
  ]
}

////////////////////////////////////////////////////////////////
// the onprem network
////////////////////////////////////////////////////////////////
resource "azurerm_resource_group" "onprem" {
  name     = var.onprem_rg
  location = var.onprem_location
}

resource "azurerm_virtual_network" "onpremvnet" {
  name                = "onpremvnet"
  address_space       = ["192.168.254.240/29"]
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name

  subnet {
    name           = "filersubnet"
    address_prefix = "192.168.254.240/29"
  }

  depends_on = [
    azurerm_resource_group.onprem
  ]
}

////////////////////////////////////////////////////////////////
// peer the networks
////////////////////////////////////////////////////////////////
resource "azurerm_virtual_network_peering" "peer-to-onprem" {
  name                      = "peertoonprem"
  resource_group_name       = module.cloud_network.vnet_resource_group
  virtual_network_name      = module.cloud_network.vnet_name
  remote_virtual_network_id = azurerm_virtual_network.onpremvnet.id

  depends_on = [
    module.cloud_network,
    azurerm_virtual_network.onpremvnet,
  ]
}

resource "azurerm_virtual_network_peering" "peer-from-onprem" {
  name                      = "peerfromonprem"
  resource_group_name       = azurerm_virtual_network.onpremvnet.resource_group_name
  virtual_network_name      = azurerm_virtual_network.onpremvnet.name
  remote_virtual_network_id = module.cloud_network.vnet_id

  depends_on = [
    module.cloud_network,
    azurerm_virtual_network.onpremvnet,
  ]
}

////////////////////////////////////////////////////////////////
// onprem filer + Moana scene
////////////////////////////////////////////////////////////////
module "onpremfiler" {
  source              = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  ssh_key_data        = var.vm_ssh_key_data
  vm_size             = var.filer_size
  unique_name         = "onpremfiler"

  // network details
  virtual_network_resource_group = azurerm_virtual_network.onpremvnet.resource_group_name
  virtual_network_name           = azurerm_virtual_network.onpremvnet.name
  virtual_network_subnet_name    = tolist(azurerm_virtual_network.onpremvnet.subnet)[0].name

  depends_on = [
    azurerm_virtual_network.onpremvnet,
    azurerm_resource_group.onprem,
  ]
}

module "download_moana" {
  source                     = "github.com/Azure/Avere/src/terraform/modules/download_moana"
  node_address               = module.vfxtcontroller.controller_address
  admin_username             = var.vm_admin_username
  admin_password             = var.vm_admin_password
  ssh_key_data               = var.vm_ssh_key_data
  ssh_port                   = var.ssh_port
  nfsfiler_address           = module.onpremfiler.primary_ip
  nfsfiler_export_path       = module.onpremfiler.core_filer_export
  island_animation_sas_url   = var.island_animation_sas_url
  island_basepackage_sas_url = var.island_basepackage_sas_url
  island_pbrt_sas_url        = var.island_pbrt_sas_url

  depends_on = [
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
    module.onpremfiler,
    module.vfxtcontroller,
  ]
}

////////////////////////////////////////////////////////////////
// controller and vFXT
////////////////////////////////////////////////////////////////
module "vfxtcontroller" {
  source                = "github.com/Azure/Avere/src/terraform/modules/controller3"
  resource_group_name   = var.cloud_rg
  create_resource_group = false
  location              = var.cloud_location
  admin_username        = var.vm_admin_username
  admin_password        = var.vm_admin_password
  ssh_key_data          = var.vm_ssh_key_data
  add_public_ip         = var.controller_add_public_ip
  ssh_port              = var.ssh_port
  vm_size               = var.controller_size

  // network details
  virtual_network_resource_group = var.cloud_rg
  virtual_network_name           = module.cloud_network.vnet_name
  virtual_network_subnet_name    = module.cloud_network.jumpbox_subnet_name

  depends_on = [
    module.cloud_network,
  ]
}

resource "avere_vfxt" "vfxt" {
  controller_address        = module.vfxtcontroller.controller_address
  controller_admin_username = var.vm_admin_username
  // ssh key takes precedence over controller password
  controller_admin_password    = var.vm_ssh_key_data != null && var.vm_ssh_key_data != "" ? "" : var.vm_admin_password
  controller_ssh_port          = var.ssh_port
  location                     = var.cloud_location
  azure_resource_group         = var.cloud_rg
  azure_network_resource_group = var.cloud_rg
  azure_network_name           = module.cloud_network.vnet_name
  azure_subnet_name            = module.cloud_network.cloud_cache_subnet_name
  vfxt_cluster_name            = var.vfxt_cluster_name
  vfxt_admin_password          = var.vfxt_cluster_password
  vfxt_ssh_key_data            = local.vfxt_ssh_key_data
  vfxt_node_count              = 3
  node_size                    = var.vfxt_use_test_sku ? "unsupported_test_SKU" : "prod_sku"

  core_filer {
    name               = "nfs1"
    fqdn_or_primary_ip = module.onpremfiler.primary_ip
    cache_policy       = var.cache_policy
    junction {
      namespace_path    = module.onpremfiler.core_filer_export
      core_filer_export = module.onpremfiler.core_filer_export
    }
  }

  depends_on = [
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
    module.onpremfiler,
    module.vfxtcontroller,
  ]
}

////////////////////////////////////////////////////////////////
// cachewarmer
////////////////////////////////////////////////////////////////
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = var.cloud_rg
  location                 = var.cloud_location
  account_kind             = "Storage" // set to storage v1 for cheapest cost on queue transactions
  account_tier             = "Standard"
  account_replication_type = "LRS"

  depends_on = [
    azurerm_resource_group.cloud,
  ]
}

module "cachewarmer_prepare_bootstrapdir" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_prepare_bootstrapdir"

  // authentication with controller
  jumpbox_address      = module.vfxtcontroller.controller_address
  jumpbox_username     = module.vfxtcontroller.controller_username
  jumpbox_password     = var.vm_admin_password
  jumpbox_ssh_key_data = var.vm_ssh_key_data

  // bootstrap directory to store the cache manager binaries and install scripts
  bootstrap_mount_address = module.onpremfiler.primary_ip
  bootstrap_export_path   = module.onpremfiler.core_filer_export
  bootstrap_subdir        = "/tools/bootstrap"

  # use the release binaries by setting build_cachewarmer to false
  build_cachewarmer = false

  depends_on = [
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
    module.onpremfiler,
    module.vfxtcontroller,
  ]
}

module "cachewarmer_manager_install" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_manager_install"

  // authentication with controller
  jumpbox_address      = module.vfxtcontroller.controller_address
  jumpbox_username     = module.vfxtcontroller.controller_username
  jumpbox_password     = var.vm_admin_password
  jumpbox_ssh_key_data = var.vm_ssh_key_data

  // bootstrap directory to install the cache manager service
  bootstrap_mount_address       = module.cachewarmer_prepare_bootstrapdir.bootstrap_mount_address
  bootstrap_export_path         = module.cachewarmer_prepare_bootstrapdir.bootstrap_export_path
  bootstrap_manager_script_path = module.cachewarmer_prepare_bootstrapdir.cachewarmer_manager_bootstrap_script_path

  // the job path
  storage_account    = azurerm_storage_account.storage.name
  storage_account_rg = azurerm_storage_account.storage.resource_group_name
  queue_name_prefix  = var.queue_prefix_name

  // the cachewarmer VMSS auth details
  vmss_user_name      = module.vfxtcontroller.controller_username
  vmss_password       = var.vm_admin_password
  vmss_ssh_public_key = var.vm_ssh_key_data
  vmss_subnet_name    = module.cloud_network.render_clients1_subnet_name
  vmss_worker_count   = length(avere_vfxt.vfxt.node_names) * 2 // 2 nodes per avere node

  // the cachewarmer install the work script
  bootstrap_worker_script_path = module.cachewarmer_prepare_bootstrapdir.cachewarmer_worker_bootstrap_script_path

  depends_on = [
    module.cachewarmer_prepare_bootstrapdir,
    avere_vfxt.vfxt,
    azurerm_storage_account.storage,
  ]
}

module "cachewarmer_worker_install" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_worker_install"

  // authentication with controller
  jumpbox_address      = module.vfxtcontroller.controller_address
  jumpbox_username     = module.vfxtcontroller.controller_username
  jumpbox_password     = var.vm_admin_password
  jumpbox_ssh_key_data = var.vm_ssh_key_data

  // bootstrap directory to install the cache manager service
  bootstrap_mount_address      = module.cachewarmer_prepare_bootstrapdir.bootstrap_mount_address
  bootstrap_export_path        = module.cachewarmer_prepare_bootstrapdir.bootstrap_export_path
  bootstrap_worker_script_path = module.cachewarmer_prepare_bootstrapdir.cachewarmer_worker_bootstrap_script_path

  // the job path
  storage_account    = azurerm_storage_account.storage.name
  storage_account_rg = azurerm_storage_account.storage.resource_group_name
  queue_name_prefix  = var.queue_prefix_name

  depends_on = [
    module.cachewarmer_manager_install,
    azurerm_storage_account.storage,
  ]
}

module "cachewarmer_submitjobs" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_submitjobs"

  // authentication with controller
  jumpbox_address      = module.vfxtcontroller.controller_address
  jumpbox_username     = module.vfxtcontroller.controller_username
  jumpbox_password     = var.vm_admin_password
  jumpbox_ssh_key_data = var.vm_ssh_key_data

  // the job path
  storage_account    = azurerm_storage_account.storage.name
  storage_account_rg = azurerm_storage_account.storage.resource_group_name
  queue_name_prefix  = var.queue_prefix_name

  // the path to warm
  warm_mount_addresses = join(",", tolist(avere_vfxt.vfxt.vserver_ip_addresses))
  warm_paths = {
    "${module.onpremfiler.core_filer_export}" : ["/tools", "/island"],
  }

  inclusion_csv    = "" // example "*.jpg,*.png"
  exclusion_csv    = "" // example "*.tgz,*.tmp"
  maxFileSizeBytes = 0

  depends_on = [
    module.cachewarmer_worker_install,
    module.download_moana,
    avere_vfxt.vfxt,
    azurerm_storage_account.storage,
  ]
}

# outputs
output "controller_username" {
  value = module.vfxtcontroller.controller_username
}

output "controller_address" {
  value = module.vfxtcontroller.controller_address
}

output "ssh_port" {
  value = var.ssh_port
}

output "ssh_command_with_avere_tunnel" {
  value = "ssh -p ${var.ssh_port} -L8443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
}

output "management_ip" {
  value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
  value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}

output "filer_address" {
  value = module.onpremfiler.primary_ip
}

output "filer_export" {
  value = module.onpremfiler.core_filer_export
}
