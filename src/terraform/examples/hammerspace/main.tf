// customize the simple VM by editing the following local variables
locals {
  // the region of the deployment
  location       = "eastus"
  admin_username = "azureuser"
  admin_password = "ReplacePassword$"

  unique_name          = "hammerspace1"
  hammerspace_image_id = ""

  // add a globally uniquename
  storage_account_name   = "REPLACE_WITH_GLOBALLY_UNIQUE_NAME"
  storage_container_name = "hammerspace"

  // virtual network and subnet details
  virtual_network_resource_group_name = "network_resource_group"
  virtual_network_name                = "rendervnet"
  ha_subnet_name                      = "cloud_filers_ha"
  data_subnet_name                    = "cloud_filers"
  data_subnet_mask_bits               = 25
  anvil_data_cluster_ip               = "10.0.2.110" // leave blank to be dynamic

  // nfs filer details
  filer_resource_group_name = "filer_resource_group"

  region_configuration = local.test_configuration

  test_configuration = {
    use_highly_available  = false
    anvil_instance_type   = "Standard_F8s_v2"
    metadata_disk_size_gb = 127

    dsx_instance_count = 1
    dsx_instance_type  = "Standard_F8s_v2"
    datadisk_size_gb   = 511

    storage_account_type = "Standard_LRS"
    // storage_account_type = "StandardSSD_LRS"
    // storage_account_type = "Premium_LRS"
  }

  artist_configuration = {
    use_highly_available = true
    anvil_instance_type  = "Standard_F16s_v2"
    dsx_instance_count   = 3

    dsx_instance_type     = "Standard_DS14_v2"
    metadata_disk_size_gb = 256
    datadisk_size_gb      = 1024

    storage_account_type = "Premium_LRS"
  }

  render_configuration = {
    use_highly_available  = true
    anvil_instance_type   = "Standard_L8s_v2"
    metadata_disk_size_gb = 256

    dsx_instance_count = 3
    dsx_instance_type  = "Standard_L32s_v2"
    datadisk_size_gb   = 0

    storage_account_type = "Premium_LRS"
  }

  // the nfs export path exported from hammerspace
  nfs_export_path = "/data"
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

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.nfsfiler.name
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  depends_on = [
    azurerm_resource_group.nfsfiler,
  ]
}

resource "azurerm_storage_container" "blob_container" {
  name                 = local.storage_container_name
  storage_account_name = azurerm_storage_account.storage.name
}

// the ephemeral filer
module "anvil" {
  source               = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil"
  resource_group_name  = azurerm_resource_group.nfsfiler.name
  location             = azurerm_resource_group.nfsfiler.location
  hammerspace_image_id = local.hammerspace_image_id
  unique_name          = local.unique_name
  admin_username       = local.admin_username
  admin_password       = local.admin_password

  anvil_configuration              = local.region_configuration.use_highly_available ? "High Availability" : "Standalone"
  anvil_instance_type              = local.region_configuration.anvil_instance_type
  anvil_metadata_disk_storage_type = local.region_configuration.storage_account_type
  anvil_metadata_disk_size         = local.region_configuration.metadata_disk_size_gb

  virtual_network_resource_group        = local.virtual_network_resource_group_name
  virtual_network_name                  = local.virtual_network_name
  virtual_network_ha_subnet_name        = local.ha_subnet_name
  virtual_network_data_subnet_name      = local.data_subnet_name
  virtual_network_data_subnet_mask_bits = local.data_subnet_mask_bits
  anvil_data_cluster_ip                 = local.anvil_data_cluster_ip

  depends_on = [
    azurerm_resource_group.nfsfiler,
  ]
}

// the ephemeral filer
module "dsx" {
  source               = "github.com/Azure/Avere/src/terraform/modules/hammerspace/dsx"
  resource_group_name  = azurerm_resource_group.nfsfiler.name
  location             = azurerm_resource_group.nfsfiler.location
  hammerspace_image_id = local.hammerspace_image_id
  unique_name          = local.unique_name
  admin_username       = local.admin_username
  admin_password       = local.admin_password

  dsx_instance_count         = local.region_configuration.dsx_instance_count
  dsx_instance_type          = local.region_configuration.dsx_instance_type
  dsx_data_disk_size         = local.region_configuration.datadisk_size_gb
  dsx_data_disk_storage_type = local.region_configuration.storage_account_type

  virtual_network_resource_group        = local.virtual_network_resource_group_name
  virtual_network_name                  = local.virtual_network_name
  virtual_network_data_subnet_name      = local.data_subnet_name
  virtual_network_data_subnet_mask_bits = local.data_subnet_mask_bits
  anvil_password                        = module.anvil.web_ui_password[0]
  anvil_data_cluster_ip                 = module.anvil.anvil_data_cluster_ip
  anvil_domain                          = module.anvil.anvil_domain

  depends_on = [
    azurerm_resource_group.nfsfiler,
    module.anvil,
  ]
}

module "anvil_configure" {
  source                       = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil-run-once-configure"
  anvil_arm_virtual_machine_id = length(module.anvil.arm_virtual_machine_ids) == 0 ? "" : module.anvil.arm_virtual_machine_ids[0]
  anvil_data_cluster_ip        = module.anvil.anvil_data_cluster_ip
  web_ui_password              = module.anvil.web_ui_password[0]
  dsx_count                    = local.region_configuration.dsx_instance_count
  nfs_export_path              = local.nfs_export_path
  anvil_hostname               = length(module.anvil.anvil_host_names) == 0 ? "" : module.anvil.anvil_host_names[0]

  depends_on = [
    module.anvil,
  ]
}

output "hammerspace_username" {
  value = module.anvil.admin_username
}

output "hammerspace_webui_username" {
  value = module.anvil.web_ui_username
}

output "hammerspace_webui_password" {
  value = module.anvil.web_ui_password[0]
}

output "anvil_data_cluster_ip" {
  value = module.anvil.anvil_data_cluster_ip
}

output "anvil_data_cluster_data_ips" {
  value = module.anvil.anvil_data_cluster_data_ips
}

output "nfs_mountable_ips" {
  value = module.dsx.dsx_ip_addresses
}

output "nfs_export_path" {
  value = local.nfs_export_path
}
