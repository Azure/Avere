// customize the simple VM by editing the following local variables
locals {
    // paste from 0.network/fourthregion output variables
    location4 = ""
    network_rg4_name = ""
    network-region4-vnet_name = ""
    network-region4-cloud_filers_ha_subnet_name = ""
    network-region4-cloud_filers_subnet_name = ""
    resource_group_unique_prefix = ""
    storage_account_name1_rg = ""
    storage_account_name1 = ""
    storage_container_name = ""

    // add the shared storage accounta globally uniquename
    storage_account_name1 = "${local.storage_account_unique_name}${local.location1}"
    storage_container_name = "sharedglobalstorage"
    
    // set the following variables to appropriate values
    admin_username = "azureuser"
    admin_password = "ReplacePassword$"
    
    // storage rg
    storage_rg4_name = "${local.resource_group_unique_prefix}stgregion4"
    
    hammerspace_image_id_4 = ""
    ad_domain = ""
    ad_user = ""
    ad_password = ""
    unique_name_4 = local.location4
    use_highly_available = false
    anvil_configuration = local.use_highly_available ? "High Availability" : "Standalone"
    // virtual network and subnet details
    data_subnet_mask_bits                = 25
    anvil_data_cluster_ip_4              = "10.3.2.240" // leave blank to be dynamic
    dsx_instance_count                   = 1

    // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    anvil_instance_type = "Standard_F8s_v2"
    // anvil_instance_type = "Standard_F16s_v2"
    // anvil_instance_type = "Standard_F32s_v2"
    // anvil_instance_type = "Standard_F48s_v2"
    //anvil_instance_type = "Standard_F16s_v2"
    // More sizes found here: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    dsx_instance_type = "Standard_F8s_v2"
    // dsx_instance_type = "Standard_F16s_v2"
    // dsx_instance_type = "Standard_F32s_v2"
    // dsx_instance_type = "Standard_F48s_v2"
    // dsx_instance_type = "Standard_F16s_v2"

    // storage_account_type = "Standard_LRS"
    // storage_account_type = "StandardSSD_LRS"
    storage_account_type = "Premium_LRS"
    
    // more disk sizes and pricing found here: https://azure.microsoft.com/en-us/pricing/details/managed-disks/
    // metadata_disk_size_gb = 127   //  P10, E10, S10
    metadata_disk_size_gb = 255   //  P15, E15, S15
    // metadata_disk_size_gb = 511   //  P20, E20, S20
    // metadata_disk_size_gb = 1023  //  P30, E30, S30
    // metadata_disk_size_gb = 2047  //  P40, E40, S40
    // metadata_disk_size_gb = 4095  //  P50, E50, S50
    // metadata_disk_size_gb = 8191  //  P60, E60, S60
    // metadata_disk_size_gb = 16383 //  P70, E70, S70
    // metadata_disk_size_gb = 32767 //  P80, E80, S80
    
    // more disk sizes and pricing found here: https://azure.microsoft.com/en-us/pricing/details/managed-disks/
    // data_disk_size_gb = 127   //  P10, E10, S10
    // data_disk_size_gb = 255   //  P15, E15, S15
    // data_disk_size_gb = 511   //  P20, E20, S20
    data_disk_size_gb = 1023  //  P30, E30, S30
    // data_disk_size_gb = 2047  //  P40, E40, S40
    //data_disk_size_gb = 4095  //  P50, E50, S50
    // data_disk_size_gb = 8191  //  P60, E60, S60
    // data_disk_size_gb = 16383 //  P70, E70, S70
    // data_disk_size_gb = 32767 //  P80, E80, S80

    # advanced scenario: add external ports to work with cloud policies example [10022, 13389]
    open_external_ports = [22,3389]
    // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
    // or if accessing from cloud shell, put "AzureCloud"
    open_external_sources = ["*"]
    dns_servers = null // set this to the dc, for example ["10.0.3.254"] could be use for domain controller
}

provider "azurerm" {
    version = "~>2.12.0"
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
    source                                = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil"
    resource_group_name                   = azurerm_resource_group.nfsfiler4.name
    location                              = azurerm_resource_group.nfsfiler4.location
    hammerspace_image_id                  = local.hammerspace_image_id_4
    unique_name                           = local.unique_name_4
    admin_username                        = local.admin_username
    admin_password                        = local.admin_password
    anvil_configuration                   = local.anvil_configuration
    anvil_instance_type                   = local.anvil_instance_type
    virtual_network_resource_group        = local.network_rg4_name
    virtual_network_name                  = local.network-region4-vnet_name
    virtual_network_ha_subnet_name        = local.network-region4-cloud_filers_ha_subnet_name
    virtual_network_data_subnet_name      = local.network-region4-cloud_filers_subnet_name
    virtual_network_data_subnet_mask_bits = local.data_subnet_mask_bits
    anvil_data_cluster_ip                 = local.anvil_data_cluster_ip_4
    anvil_metadata_disk_storage_type      = local.storage_account_type
    anvil_metadata_disk_size              = local.metadata_disk_size_gb

    module_depends_on = [azurerm_resource_group.nfsfiler4.id]
}

// the ephemeral filer
module "dsx4" {
    source                                = "github.com/Azure/Avere/src/terraform/modules/hammerspace/dsx"
    resource_group_name                   = azurerm_resource_group.nfsfiler4.name
    location                              = azurerm_resource_group.nfsfiler4.location
    hammerspace_image_id                  = local.hammerspace_image_id_4
    unique_name                           = local.unique_name_4
    admin_username                        = local.admin_username
    admin_password                        = local.admin_password
    dsx_instance_count                    = local.dsx_instance_count
    dsx_instance_type                     = local.dsx_instance_type
    virtual_network_resource_group        = local.network_rg4_name
    virtual_network_name                  = local.network-region4-vnet_name
    virtual_network_data_subnet_name      = local.network-region4-cloud_filers_subnet_name
    virtual_network_data_subnet_mask_bits = local.data_subnet_mask_bits
    anvil_password                        = module.anvil4.web_ui_password
    anvil_data_cluster_ip                 = module.anvil4.anvil_data_cluster_ip
    anvil_domain                          = module.anvil4.anvil_domain
    dsx_data_disk_storage_type            = local.storage_account_type
    dsx_data_disk_size                    = local.data_disk_size_gb
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

    azure_storage_account = local.storage_account_name1
    azure_storage_account_key = data.azurerm_storage_account.sharedstorageaccount.primary_access_key
    azure_storage_account_container = local.storage_container_name

    module_depends_on = module.anvil4.module_depends_on_ids
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
