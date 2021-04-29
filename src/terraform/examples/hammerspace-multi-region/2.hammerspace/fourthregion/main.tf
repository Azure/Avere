// customize the simple VM by editing the following local variables
locals {
  // paste from 0.network/fourthregion output variables
  location4                                   = ""
  network_rg4_name                            = ""
  network-region4-vnet_name                   = ""
  network-region4-cloud_filers_ha_subnet_name = ""
  network-region4-cloud_filers_subnet_name    = ""
  resource_group_unique_prefix                = ""
  storage_account_name1_rg                    = ""

  // add the shared storage accounta globally uniquename
  storage_account_name1  = "${local.storage_account_unique_name}${local.location1}"
  storage_container_name = "sharedglobalstorage"

  // set the following variables to appropriate values
  admin_username = "azureuser"
  admin_password = "ReplacePassword$"

  // storage rg
  storage_rg4_name = "${local.resource_group_unique_prefix}stgregion4"

  hammerspace_image_id_4 = ""
  ad_domain              = ""
  ad_user                = ""
  ad_password            = ""
  unique_name_4          = local.location4
  // virtual network and subnet details
  data_subnet_mask_bits   = 25
  anvil_data_cluster_ip_4 = "10.3.2.240" // leave blank to be dynamic
  dsx_instance_count      = 1

  region4_configuration = local.test_configuration

  test_configuration = {
    use_highly_available = false
    // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    anvil_instance_type   = "Standard_F8s_v2"
    metadata_disk_size_gb = 127

    dsx_instance_count = 1
    // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    dsx_instance_type = "Standard_F8s_v2"
    datadisk_size_gb  = 511

    storage_account_type = "Standard_LRS"
    // storage_account_type = "StandardSSD_LRS"
    // storage_account_type = "Premium_LRS"
  }

  artist_configuration = {
    use_highly_available = false
    // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    anvil_instance_type = "Standard_F16s_v2"
    dsx_instance_count  = 3

    // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    dsx_instance_type     = "Standard_DS14_v2"
    metadata_disk_size_gb = 256
    datadisk_size_gb      = 1024

    // storage_account_type = "Standard_LRS"
    // storage_account_type = "StandardSSD_LRS"
    storage_account_type = "Premium_LRS"
  }

  render_configuration = {
    use_highly_available = false
    // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    anvil_instance_type   = "Standard_F16s_v2"
    metadata_disk_size_gb = 256

    dsx_instance_count = 3
    // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    dsx_instance_type = "Standard_L32s_v2"
    datadisk_size_gb  = 0

    // storage_account_type = "Standard_LRS"
    // storage_account_type = "StandardSSD_LRS"
    storage_account_type = "Premium_LRS"
  }

  # advanced scenario: add external ports to work with cloud policies example [10022, 13389]
  open_external_ports = [22, 3389]
  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  open_external_sources = ["*"]
  dns_servers           = null // set this to the dc, for example ["10.0.3.254"] could be use for domain controller
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

////////////////////////////////////////////////////////////////
// STORAGE
////////////////////////////////////////////////////////////////

resource "azurerm_resource_group" "nfsfiler4" {
  name     = local.storage_rg4_name
  location = local.location4
}

data "azurerm_storage_account" "sharedstorageaccount" {
  name                = local.storage_account_name1
  resource_group_name = local.storage_account_name1_rg
}

////////////////////////////////////////////////////////////////
// Hammerspace
////////////////////////////////////////////////////////////////

// the ephemeral filer
module "anvil4" {
  source               = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil"
  resource_group_name  = azurerm_resource_group.nfsfiler4.name
  location             = azurerm_resource_group.nfsfiler4.location
  hammerspace_image_id = local.hammerspace_image_id_4
  unique_name          = local.unique_name_4
  admin_username       = local.admin_username
  admin_password       = local.admin_password

  anvil_configuration              = local.region4_configuration.use_highly_available ? "High Availability" : "Standalone"
  anvil_instance_type              = local.region4_configuration.anvil_instance_type
  anvil_metadata_disk_size         = local.region4_configuration.metadata_disk_size_gb
  anvil_metadata_disk_storage_type = local.region4_configuration.storage_account_type

  virtual_network_resource_group        = local.network_rg4_name
  virtual_network_name                  = local.network-region4-vnet_name
  virtual_network_ha_subnet_name        = local.network-region4-cloud_filers_ha_subnet_name
  virtual_network_data_subnet_name      = local.network-region4-cloud_filers_subnet_name
  virtual_network_data_subnet_mask_bits = local.data_subnet_mask_bits
  anvil_data_cluster_ip                 = local.anvil_data_cluster_ip_4

  depends_on = [
    azurerm_resource_group.nfsfiler4,
  ]
}

// the ephemeral filer
module "dsx4" {
  source               = "github.com/Azure/Avere/src/terraform/modules/hammerspace/dsx"
  resource_group_name  = azurerm_resource_group.nfsfiler4.name
  location             = azurerm_resource_group.nfsfiler4.location
  hammerspace_image_id = local.hammerspace_image_id_4
  unique_name          = local.unique_name_4
  admin_username       = local.admin_username
  admin_password       = local.admin_password

  dsx_instance_count         = local.region4_configuration.dsx_instance_count
  dsx_instance_type          = local.region4_configuration.dsx_instance_type
  dsx_data_disk_size         = local.region4_configuration.datadisk_size_gb
  dsx_data_disk_storage_type = local.region4_configuration.storage_account_type

  virtual_network_resource_group        = local.network_rg4_name
  virtual_network_name                  = local.network-region4-vnet_name
  virtual_network_data_subnet_name      = local.network-region4-cloud_filers_subnet_name
  virtual_network_data_subnet_mask_bits = local.data_subnet_mask_bits
  anvil_password                        = module.anvil4.web_ui_password
  anvil_data_cluster_ip                 = module.anvil4.anvil_data_cluster_ip
  anvil_domain                          = module.anvil4.anvil_domain

  depends_on = [
    azurerm_resource_group.nfsfiler4,
    module.anvil4,
  ]
}

module "anvil_configure4" {
  source                       = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil-run-once-configure"
  anvil_arm_virtual_machine_id = length(module.anvil4.arm_virtual_machine_ids) == 0 ? "" : module.anvil4.arm_virtual_machine_ids[0]
  anvil_data_cluster_ip        = module.anvil4.anvil_data_cluster_ip
  web_ui_password              = module.anvil4.web_ui_password
  dsx_count                    = local.dsx_instance_count
  anvil_hostname               = length(module.anvil4.anvil_host_names) == 0 ? "" : module.anvil4.anvil_host_names[0]

  local_site_name  = local.unique_name_4
  ad_domain        = local.ad_domain
  ad_user          = local.ad_user
  ad_user_password = local.ad_password

  azure_storage_account           = local.storage_account_name1
  azure_storage_account_key       = data.azurerm_storage_account.sharedstorageaccount.primary_access_key
  azure_storage_account_container = local.storage_container_name

  depends_on = [
    module.anvil4,
    data.azurerm_storage_account.sharedstorageaccount,
  ]
}

output "hammerspace_webui_username" {
  value = module.anvil4.web_ui_username
}

output "hammerspace_webui_password_4" {
  value = module.anvil4.web_ui_password
}

output "anvil_data_cluster_ip_4" {
  value = module.anvil4.anvil_data_cluster_ip
}

output "nfs_mountable_ips_4" {
  value = module.dsx4.dsx_ip_addresses
}
