// customize the simple VM by editing the following local variables
locals {
  // the region of the deployment
  location          = "eastus"
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
  ssh_port        = 22

  // network details
  network_resource_group_name = "network_resource_group"

  // nfs filer details
  filer_resource_group_name = "filer_resource_group"
  unique_name               = "hammerspace1"
  hammerspace_image_id      = ""
  use_highly_available      = false
  anvil_configuration       = local.use_highly_available ? "High Availability" : "Standalone"
  data_subnet_mask_bits     = 25
  anvil_data_cluster_ip     = "10.0.2.110" // leave blank to be dynamic
  dsx_instance_count        = 1
  // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
  // vm_size = "Standard_F16s_v2"
  // vm_size = "Standard_F32s_v2"
  // vm_size = "Standard_F48s_v2"
  anvil_instance_type = "Standard_F16s_v2"
  // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
  // vm_size = "Standard_F16s_v2"
  // vm_size = "Standard_F32s_v2"
  // vm_size = "Standard_F48s_v2"
  dsx_instance_type = "Standard_F16s_v2"

  // storage_account_type = "Standard_LRS"
  // storage_account_type = "StandardSSD_LRS"
  storage_account_type = "Premium_LRS"

  // more disk sizes and pricing found here: https://azure.microsoft.com/en-us/pricing/details/managed-disks/
  // disk_size_gb = 127   //  P10, E10, S10
  metadata_disk_size_gb = 255 //  P15, E15, S15
  // disk_size_gb = 511   //  P20, E20, S20
  // disk_size_gb = 1023  //  P30, E30, S30
  // disk_size_gb = 2047  //  P40, E40, S40
  // disk_size_gb = 4095  //  P50, E50, S50
  // disk_size_gb = 8191  //  P60, E60, S60
  // disk_size_gb = 16383 //  P70, E70, S70
  // metadata_disk_size_gb = 32767 //  P80, E80, S80

  // more disk sizes and pricing found here: https://azure.microsoft.com/en-us/pricing/details/managed-disks/
  // disk_size_gb = 127   //  P10, E10, S10
  // disk_size_gb = 255   //  P15, E15, S15
  // disk_size_gb = 511   //  P20, E20, S20
  // disk_size_gb = 1023  //  P30, E30, S30
  // disk_size_gb = 2047  //  P40, E40, S40
  datadisk_size_gb = 4095 //  P50, E50, S50
  // disk_size_gb = 8191  //  P60, E60, S60
  // disk_size_gb = 16383 //  P70, E70, S70
  // data_disk_size_gb = 32767 //  P80, E80, S80

  hammerspace_filer_nfs_export_path = "/assets"

  // vfxt details
  vfxt_resource_group_name = "vfxt_resource_group"
  // if you are running a locked down network, set controller_add_public_ip to false
  controller_add_public_ip = true
  vfxt_cluster_name        = "vfxt"
  vfxt_cluster_password    = "VFXT_PASSWORD"
  vfxt_ssh_key_data        = local.vm_ssh_key_data
  namespace_path           = "/assets"
  // vfxt cache polies
  //  "Clients Bypassing the Cluster"
  //  "Read Caching"
  //  "Read and Write Caching"
  //  "Full Caching"
  //  "Transitioning Clients Before or After a Migration"
  cache_policy = "Clients Bypassing the Cluster"

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

// the render network
module "network" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_resource_group_name
  location            = local.location

  open_external_ports   = local.open_external_ports
  open_external_sources = local.open_external_sources
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.location
}

// the ephemeral filer
module "anvil" {
  source                                = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil"
  resource_group_name                   = azurerm_resource_group.nfsfiler.name
  location                              = azurerm_resource_group.nfsfiler.location
  hammerspace_image_id                  = local.hammerspace_image_id
  unique_name                           = local.unique_name
  admin_username                        = local.vm_admin_username
  admin_password                        = local.vm_admin_password
  anvil_configuration                   = local.anvil_configuration
  anvil_instance_type                   = local.anvil_instance_type
  virtual_network_resource_group        = local.network_resource_group_name
  virtual_network_name                  = module.network.vnet_name
  virtual_network_ha_subnet_name        = module.network.cloud_filers_ha_subnet_name
  virtual_network_data_subnet_name      = module.network.cloud_filers_subnet_name
  virtual_network_data_subnet_mask_bits = local.data_subnet_mask_bits
  anvil_data_cluster_ip                 = local.anvil_data_cluster_ip
  anvil_metadata_disk_storage_type      = local.storage_account_type
  anvil_metadata_disk_size              = local.metadata_disk_size_gb

  depends_on = [
    module.network,
    azurerm_resource_group.nfsfiler,
  ]
}

// the ephemeral filer
module "dsx" {
  source                                = "github.com/Azure/Avere/src/terraform/modules/hammerspace/dsx"
  resource_group_name                   = azurerm_resource_group.nfsfiler.name
  location                              = azurerm_resource_group.nfsfiler.location
  hammerspace_image_id                  = local.hammerspace_image_id
  unique_name                           = local.unique_name
  admin_username                        = local.vm_admin_username
  admin_password                        = local.vm_admin_password
  dsx_instance_count                    = local.dsx_instance_count
  dsx_instance_type                     = local.dsx_instance_type
  virtual_network_resource_group        = local.network_resource_group_name
  virtual_network_name                  = module.network.vnet_name
  virtual_network_data_subnet_name      = module.network.cloud_filers_subnet_name
  virtual_network_data_subnet_mask_bits = local.data_subnet_mask_bits
  anvil_password                        = module.anvil.web_ui_password
  anvil_data_cluster_ip                 = module.anvil.anvil_data_cluster_ip
  anvil_domain                          = module.anvil.anvil_domain
  dsx_data_disk_storage_type            = local.storage_account_type
  dsx_data_disk_size                    = local.datadisk_size_gb

  depends_on = [
    module.network,
    azurerm_resource_group.nfsfiler,
    module.anvil,
  ]
}

module "anvil_configure" {
  source                       = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil-run-once-configure"
  anvil_arm_virtual_machine_id = length(module.anvil.arm_virtual_machine_ids) == 0 ? "" : module.anvil.arm_virtual_machine_ids[0]
  anvil_data_cluster_ip        = module.anvil.anvil_data_cluster_ip
  web_ui_password              = module.anvil.web_ui_password
  dsx_count                    = local.dsx_instance_count
  nfs_export_path              = local.hammerspace_filer_nfs_export_path
  anvil_hostname               = length(module.anvil.anvil_host_names) == 0 ? "" : module.anvil.anvil_host_names[0]

  depends_on = [
    module.anvil,
  ]
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
  image_id                    = local.controller_image_id
  alternative_resource_groups = local.alternative_resource_groups
  ssh_port                    = local.ssh_port

  // network details
  virtual_network_resource_group = local.network_resource_group_name
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.jumpbox_subnet_name

  depends_on = [
    module.network,
  ]
}

// the vfxt
resource "avere_vfxt" "vfxt" {
  controller_address        = module.vfxtcontroller.controller_address
  controller_admin_username = module.vfxtcontroller.controller_username
  // ssh key takes precedence over controller password
  controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
  controller_ssh_port       = local.ssh_port
  enable_nlm                = false

  location                     = local.location
  azure_resource_group         = local.vfxt_resource_group_name
  azure_network_resource_group = local.network_resource_group_name
  azure_network_name           = module.network.vnet_name
  azure_subnet_name            = module.network.cloud_cache_subnet_name
  vfxt_cluster_name            = local.vfxt_cluster_name
  vfxt_admin_password          = local.vfxt_cluster_password
  vfxt_ssh_key_data            = local.vfxt_ssh_key_data
  vfxt_node_count              = 3
  image_id                     = local.vfxt_image_id

  core_filer {
    name               = "nfs1"
    fqdn_or_primary_ip = join(" ", module.dsx.dsx_ip_addresses)
    cache_policy       = local.cache_policy
    junction {
      namespace_path    = local.namespace_path
      core_filer_export = local.hammerspace_filer_nfs_export_path
    }
  }

  // terraform is not creating the implicit dependency on the controller module
  // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
  // to work around, add the explicit dependency
  depends_on = [
    module.vfxtcontroller,
    module.anvil_configure,
  ]
}

output "hammerspace_filer_addresses" {
  value = module.dsx.dsx_ip_addresses
}

output "hammerspace_filer_export" {
  value = local.hammerspace_filer_nfs_export_path
}

output "hammerspace_webui_address" {
  value = module.anvil.anvil_data_cluster_ip
}

output "hammerspace_webui_username" {
  value = module.anvil.web_ui_username
}

output "hammerspace_webui_password" {
  value = module.anvil.web_ui_password
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
