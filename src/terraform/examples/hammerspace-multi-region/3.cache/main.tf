////////////////////////////////////////////////////////////////////////////////////////
// WARNING: if you get an error deploying, please review https://aka.ms/avere-tf-prereqs
////////////////////////////////////////////////////////////////////////////////////////
locals {
  // paste from 0.network output variables
  location1                                   = ""
  network_rg1_name                            = ""
  network-region1-vnet_name                   = ""
  network-region1-cloud_filers_ha_subnet_name = ""
  network-region1-cloud_filers_subnet_name    = ""
  network-region1-jumpbox_subnet_name         = ""
  network-region1-cloud_cache_subnet_name     = ""
  resource_group_unique_prefix                = ""

  // paste from 2.hammerspace output variables
  nfs_mountable_ips_1 = []

  // set the following variables to appropriate values
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
  ssh_port        = 22

  // vfxt details
  vfxt_resource_group_name = "${local.resource_group_unique_prefix}vfxtregion1"
  // if you are running a locked down network, set controller_add_public_ip to false
  controller_add_public_ip = true
  vfxt_cluster_name        = "vfxt"
  vfxt_cluster_password    = "VFXT_PASSWORD"
  namespace_path           = "/assets"
  // vfxt cache polies
  //  "Clients Bypassing the Cluster"
  //  "Read Caching"
  //  "Read and Write Caching"
  //  "Full Caching"
  //  "Transitioning Clients Before or After a Migration"
  cache_policy = "Clients Bypassing the Cluster"

  // cifs setting
  cifs_ad_domain           = "rendering.com"
  cifs_netbios_domain_name = "RENDERING"
  cifs_dc_addreses         = "10.0.3.254"
  cifs_server_name         = "vfxt"
  cifs_username            = "azureuser"
  cifs_password            = "ReplacePassword$"
  dns_domain               = "rendering.com"
  dns_search               = "rendering.com"

  // storage account hosting the queue
  storage_account_name = "storageaccount"
  queue_prefix_name    = "cachewarmer"

  // advanced scenario: vfxt and controller image ids, leave this null, unless not using default marketplace
  controller_image_id = null
  vfxt_image_id       = null
  // advanced scenario: put the custom image resource group here
  alternative_resource_groups = []
  // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
  open_external_ports = [local.ssh_port, 3389]
  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  open_external_sources = ["*"]
}

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

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = local.vfxt_resource_group_name
  location                 = local.location1
  account_kind             = "Storage" // set to storage v1 for cheapest cost on queue transactions
  account_tier             = "Standard"
  account_replication_type = "LRS"

  depends_on = [
    module.vfxtcontroller,
  ]
}

// the vfxt controller
module "vfxtcontroller" {
  source                      = "github.com/Azure/Avere/src/terraform/modules/controller3"
  resource_group_name         = local.vfxt_resource_group_name
  location                    = local.location1
  admin_username              = local.vm_admin_username
  admin_password              = local.vm_admin_password
  ssh_key_data                = local.vm_ssh_key_data
  add_public_ip               = local.controller_add_public_ip
  image_id                    = local.controller_image_id
  alternative_resource_groups = local.alternative_resource_groups
  ssh_port                    = local.ssh_port

  // network details
  virtual_network_resource_group = local.network_rg1_name
  virtual_network_name           = local.network-region1-vnet_name
  virtual_network_subnet_name    = local.network-region1-jumpbox_subnet_name
}

// the vfxt
resource "avere_vfxt" "vfxt" {
  controller_address        = module.vfxtcontroller.controller_address
  controller_admin_username = module.vfxtcontroller.controller_username
  // ssh key takes precedence over controller password
  controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
  controller_ssh_port       = local.ssh_port
  enable_nlm                = false

  location                     = local.location1
  azure_resource_group         = local.vfxt_resource_group_name
  azure_network_resource_group = local.network_rg1_name
  azure_network_name           = local.network-region1-vnet_name
  azure_subnet_name            = local.network-region1-cloud_cache_subnet_name
  vfxt_cluster_name            = local.vfxt_cluster_name
  vfxt_admin_password          = local.vfxt_cluster_password
  vfxt_node_count              = 3
  image_id                     = local.vfxt_image_id

  cifs_ad_domain           = local.cifs_ad_domain
  cifs_netbios_domain_name = local.cifs_netbios_domain_name
  cifs_dc_addreses         = local.cifs_dc_addreses
  cifs_server_name         = local.cifs_server_name
  cifs_username            = local.cifs_username
  cifs_password            = local.cifs_password
  dns_domain               = local.dns_domain
  dns_search               = local.dns_search

  core_filer {
    name               = "nfs1"
    fqdn_or_primary_ip = join(" ", local.nfs_mountable_ips_1)
    cache_policy       = local.cache_policy
    junction {
      namespace_path    = local.namespace_path
      core_filer_export = local.namespace_path
    }
  }

  // terraform is not creating the implicit dependency on the controller module
  // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
  // to work around, add the explicit dependency
  depends_on = [
    module.vfxtcontroller,
  ]
}

module "cachewarmer_build" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_build"

  // authentication with controller
  node_address   = module.vfxtcontroller.controller_address
  admin_username = module.vfxtcontroller.controller_username
  admin_password = local.vm_admin_password
  ssh_key_data   = local.vm_ssh_key_data

  // bootstrap directory to store the cache manager binaries and install scripts
  bootstrap_mount_address = tolist(avere_vfxt.vfxt.vserver_ip_addresses)[0]
  bootstrap_export_path   = local.namespace_path

  depends_on = [
    avere_vfxt.vfxt,
    module.vfxtcontroller,
  ]
}

module "cachewarmer_manager_install" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_manager_install"

  // authentication with controller
  node_address   = module.vfxtcontroller.controller_address
  admin_username = module.vfxtcontroller.controller_username
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
  vmss_user_name      = module.vfxtcontroller.controller_username
  vmss_password       = local.vm_admin_password
  vmss_ssh_public_key = local.vm_ssh_key_data
  vmss_subnet_name    = local.network-region1-render_clients1_subnet_name

  depends_on = [
    module.cachewarmer_build,
  ]
}

output "controller_username" {
  value = module.vfxtcontroller.controller_username
}

output "controller_address" {
  value = module.vfxtcontroller.controller_address
}

output "ssh_command_with_avere_tunnel" {
  value = "ssh -p ${local.ssh_port} -L8443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
}

output "management_ip" {
  value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
  value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}

output "mount_namespace_path" {
  value = local.namespace_path
}
