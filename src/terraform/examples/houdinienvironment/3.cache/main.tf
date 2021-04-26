// customize the simple VM by editing the following local variables
locals {
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
  ssh_port        = 22

  // vfxt details
  vfxt_resource_group_name = "houdini_vfxt_rg"
  // if you are running a locked down network, set controller_add_public_ip to false
  controller_add_public_ip = true
  vfxt_cluster_name        = "vfxt"
  vfxt_cluster_password    = "VFXT_PASSWORD"
  vfxt_ssh_key_data        = local.vm_ssh_key_data

  // replace below variables with the infrastructure variables from 0.network
  location                       = ""
  vnet_cloud_cache_subnet_name   = ""
  vnet_jumpbox_subnet_name       = ""
  vnet_name                      = ""
  vnet_render_clients1_subnet_id = ""
  vnet_resource_group            = ""

  // either replace below variables from 
  //  1.storage/blobstorage,
  use_blob_storage     = false
  storage_account_name = ""
  //storage_resource_group_name = ""
  //  or 1.storage/nfsfiler
  use_nfs_storage             = false
  filer_address               = ""
  filer_export                = ""
  storage_resource_group_name = ""

  // advanced scenarios: the variables below raraly need changing
  // in addition to storage account put the custom image resource group here
  alternative_resource_groups = [local.storage_resource_group_name]
  // cloud filer details
  junction_namespace_path_clfs  = "/houdiniclfs"
  junction_namespace_path_filer = "/houdinifiler"
  // only for the blob storage
  storage_container_name = "cache"
  // only for the nfs filer storage
  // vfxt cache polies
  //  "Clients Bypassing the Cluster"
  //  "Read Caching"
  //  "Read and Write Caching"
  //  "Full Caching"
  //  "Transitioning Clients Before or After a Migration"
  cache_policy = "Clients Bypassing the Cluster"

  // cifs related settings, dns is required to find the corefiler
  // as corefiler is required to have a dns name an not an ip
  dns_server       = "" // example "10.0.3.4"
  dns_domain       = "" // example "rendering.com"
  cifs_ad_domain   = "" // example "rendering.com"
  cifs_server_name = local.vfxt_cluster_name
  cifs_username    = ""
  cifs_password    = ""
  //cifs_flatfile_passwd_b64z = base64gzip(file("${path.module}/avere-user.txt"))
  //cifs_flatfile_group_b64z = base64gzip(file("${path.module}/avere-group.txt"))
  // OU is optional
  cifs_organizational_unit = "" // example "OU=avere technology,DC=rendering,DC=com"

  // cifs nfs corefiler share name
  cifs_nfs_corefiler_share_name           = "houdinifiler"
  cifs_cloud_storage_corefiler_share_name = "houdiniclfs"
  cifs_share_ace                          = "" // leave empty for Everyone, otherwise example "azureuser(ALLOW,FULL) azureuser2(ALLOW,READ)"
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

// the vfxt controller
module "vfxtcontroller" {
  source                      = "github.com/Azure/Avere/src/terraform/modules/controller3"
  resource_group_name         = local.vfxt_resource_group_name
  location                    = local.location
  admin_username              = local.vm_admin_username
  admin_password              = local.vm_admin_password
  ssh_key_data                = local.vm_ssh_key_data
  add_public_ip               = local.controller_add_public_ip
  alternative_resource_groups = local.alternative_resource_groups
  ssh_port                    = local.ssh_port

  // network details
  virtual_network_resource_group = local.vnet_resource_group
  virtual_network_name           = local.vnet_name
  virtual_network_subnet_name    = local.vnet_jumpbox_subnet_name
}

// the vfxt
resource "avere_vfxt" "vfxt" {
  controller_address        = module.vfxtcontroller.controller_address
  controller_admin_username = module.vfxtcontroller.controller_username
  // ssh key takes precedence over controller password
  controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
  controller_ssh_port       = local.ssh_port

  // network
  azure_network_resource_group = local.vnet_resource_group
  azure_network_name           = local.vnet_name
  azure_subnet_name            = local.vnet_cloud_cache_subnet_name

  location             = local.location
  azure_resource_group = local.vfxt_resource_group_name
  vfxt_cluster_name    = local.vfxt_cluster_name
  vfxt_admin_password  = local.vfxt_cluster_password
  vfxt_ssh_key_data    = local.vfxt_ssh_key_data
  vfxt_node_count      = 3

  // cifs related settings:
  dns_server       = local.dns_server
  dns_domain       = local.dns_domain
  cifs_ad_domain   = local.cifs_ad_domain
  cifs_server_name = local.cifs_server_name
  cifs_username    = local.cifs_username
  cifs_password    = local.cifs_password
  //cifs_flatfile_passwd_b64z = local.cifs_flatfile_passwd_b64z
  //cifs_flatfile_group_b64z = local.cifs_flatfile_group_b64z
  // OU is optional, uncomment if necessary
  cifs_organizational_unit = local.cifs_organizational_unit

  global_custom_settings = [
    "vcm.disableReadAhead AB 1",
    "cluster.ctcConnMult CE 24",
    "cluster.CtcBackEndTimeout KO 220000000",
    "cluster.NfsBackEndTimeout VO 100000000",
    "cluster.NfsFrontEndCwnd EK 1",
  ]

  dynamic "azure_storage_filer" {
    for_each = local.use_blob_storage ? ["use_blob_storage"] : []
    content {
      account_name            = local.storage_account_name
      container_name          = local.storage_container_name
      junction_namespace_path = local.junction_namespace_path_clfs
      cifs_share_name         = local.cifs_nfs_corefiler_share_name
      cifs_share_ace          = local.cifs_share_ace
      custom_settings = [
        "client_rt_preferred FE 524288",
        "client_wt_preferred NO 524288",
        "nfsConnMult YW 20",
        "autoWanOptimize YF 2",
        "always_forward OZ 1",
      ]
    }
  }

  dynamic "core_filer" {
    for_each = local.use_nfs_storage ? ["use_nfs_storage"] : []
    content {
      name               = "nfs1"
      fqdn_or_primary_ip = local.filer_address
      cache_policy       = local.cache_policy
      cifs_share_name    = local.cifs_cloud_storage_corefiler_share_name
      cifs_share_ace     = local.cifs_share_ace
      custom_settings = [
        "client_rt_preferred FE 524288",
        "client_wt_preferred NO 524288",
        "nfsConnMult YW 20",
        "autoWanOptimize YF 2",
        "always_forward OZ 1",
      ]
      junction {
        namespace_path    = local.junction_namespace_path_filer
        core_filer_export = local.filer_export
      }
    }
  }

  // terraform is not creating the implicit dependency on the controller module
  // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
  // to work around, add the explicit dependency
  depends_on = [
    module.vfxtcontroller,
  ]
}

// the vfxt controller
module "mount_nfs" {
  source          = "github.com/Azure/Avere/src/terraform/modules/mount_nfs"
  node_address    = module.vfxtcontroller.controller_address
  admin_username  = local.vm_admin_username
  admin_password  = local.vm_admin_password
  ssh_port        = local.ssh_port
  ssh_key_data    = local.vm_ssh_key_data
  mount_dir       = "/mnt/nfs"
  nfs_address     = tolist(avere_vfxt.vfxt.vserver_ip_addresses)[0]
  nfs_export_path = local.use_nfs_storage ? local.junction_namespace_path_filer : local.junction_namespace_path_clfs
}

output "controller_username" {
  value = module.vfxtcontroller.controller_username
}

output "controller_address" {
  value = module.vfxtcontroller.controller_address
}

output "ssh_command_with_avere_tunnel" {
  value = "\"ssh -p ${local.ssh_port} -L8443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address
}

output "management_ip" {
  value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
  value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}

output "mount_path" {
  value = local.use_nfs_storage ? local.junction_namespace_path_filer : local.junction_namespace_path_clfs
}
