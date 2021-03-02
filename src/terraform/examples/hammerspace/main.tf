// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    admin_username = "azureuser"
    admin_password = "ReplacePassword$"

    unique_name = "hammerspace1"
    hammerspace_image_id = ""
    use_highly_available = false
    anvil_configuration = local.use_highly_available ? "High Availability" : "Standalone"
    
    // virtual network and subnet details
    virtual_network_resource_group_name  = "network_resource_group"
    virtual_network_name                 = "rendervnet"
    ha_subnet_name                       = "cloud_filers_ha"
    data_subnet_name                     = "cloud_filers"
    anvil_data_cluster_ip                = "" // leave blank to be dynamic
    dsx_instance_count                   = 1

    // nfs filer details
    filer_resource_group_name = "filer_resource_group"

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
    metadata_disk_size_gb = 255   //  P15, E15, S15
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
    datadisk_size_gb = 4095  //  P50, E50, S50
    // disk_size_gb = 8191  //  P60, E60, S60
    // disk_size_gb = 16383 //  P70, E70, S70
    // data_disk_size_gb = 32767 //  P80, E80, S80
    nfs_export_path = "/data"
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

resource "azurerm_resource_group" "nfsfiler" {
    name     = local.filer_resource_group_name
    location = local.location
}

// the ephemeral filer
module "anvil" {
    source                           = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil"
    resource_group_name              = azurerm_resource_group.nfsfiler.name
    location                         = azurerm_resource_group.nfsfiler.location
    hammerspace_image_id             = local.hammerspace_image_id
    unique_name                      = local.unique_name
    admin_username                   = local.admin_username
    admin_password                   = local.admin_password
    anvil_configuration              = local.anvil_configuration
    anvil_instance_type              = local.anvil_instance_type
    virtual_network_resource_group   = local.virtual_network_resource_group_name
    virtual_network_name             = local.virtual_network_name
    virtual_network_ha_subnet_name   = local.ha_subnet_name
    virtual_network_data_subnet_name = local.data_subnet_name
    anvil_data_cluster_ip            = local.anvil_data_cluster_ip
    anvil_metadata_disk_storage_type = local.storage_account_type
    anvil_metadata_disk_size         = local.metadata_disk_size_gb
}

// the ephemeral filer
module "dsx" {
    source                           = "github.com/Azure/Avere/src/terraform/modules/hammerspace/dsx"
    resource_group_name              = azurerm_resource_group.nfsfiler.name
    location                         = azurerm_resource_group.nfsfiler.location
    hammerspace_image_id             = local.hammerspace_image_id
    unique_name                      = local.unique_name
    admin_username                   = local.admin_username
    admin_password                   = local.admin_password
    dsx_instance_count               = local.dsx_instance_count
    dsx_instance_type                = local.dsx_instance_type
    virtual_network_resource_group   = local.virtual_network_resource_group_name
    virtual_network_name             = local.virtual_network_name
    virtual_network_data_subnet_name = local.data_subnet_name
    anvil_data_cluster_ip            = module.anvil.anvil_data_cluster_ip
    anvil_data_cluster_ip_mask_bits  = module.anvil.anvil_data_cluster_ip_mask_bits
    anvil_domain                     = module.anvil.anvil_domain
    dsx_data_disk_storage_type       = local.storage_account_type
    dsx_data_disk_size               = local.datadisk_size_gb
}

module "anvil_configure" {
    source                       = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil-run-once-configure"
    anvil_arm_virtual_machine_id = length(module.anvil.arm_virtual_machine_ids) == 0 ? "" : module.anvil.arm_virtual_machine_ids[0]
    anvil_data_cluster_ip        = module.anvil.anvil_data_cluster_ip
    web_ui_password              = module.anvil.web_ui_password
    dsx_count                    = local.dsx_instance_count
    nfs_export_path              = local.nfs_export_path
    anvil_hostname               = length(module.anvil.anvil_host_names) == 0 ? "" : module.anvil.anvil_host_names[0]

    module_depends_on = module.anvil.module_depends_on_ids
}

output "hammerspace_username" {
    value = module.anvil.admin_username
}

output "hammerspace_webui_username" {
    value = module.anvil.web_ui_username
}

output "hammerspace_webui_password" {
    value = module.anvil.web_ui_password
}

output "anvil_data_cluster_ip" {
    value = module.anvil.anvil_data_cluster_ip
}
