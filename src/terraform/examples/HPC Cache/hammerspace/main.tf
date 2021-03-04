// customize the HPC Cache by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    
    // network details
    network_resource_group_name = "network_resource_group"
    
    // hpc cache details
    hpc_cache_resource_group_name = "hpc_cache_resource_group"

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
    cache_name = "uniquename"

    // usage model
    //    WRITE_AROUND
    //    READ_HEAVY_INFREQ
    //    WRITE_WORKLOAD_15
    usage_model = "READ_HEAVY_INFREQ"

    // nfs filer related variables
    filer_resource_group_name = "filer_resource_group"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    
    unique_name           = "hammerspace1"
    hammerspace_image_id  = ""
    use_highly_available  = false
    anvil_configuration   = local.use_highly_available ? "High Availability" : "Standalone"
    anvil_data_cluster_ip = "10.0.2.110" // leave blank to be dynamic
    dsx_instance_count    = 1
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

    hammerspace_filer_nfs_export_path = "/data"
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

// the render network
module "network" {
    source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
    resource_group_name = local.network_resource_group_name
    location            = local.location
}

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
}

resource "azurerm_hpc_cache" "hpc_cache" {
  name                = local.cache_name
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  cache_size_in_gb    = local.cache_size
  subnet_id           = module.network.cloud_cache_subnet_id
  sku_name            = local.cache_throughput
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
    admin_username                   = local.vm_admin_username
    admin_password                   = local.vm_admin_password
    anvil_configuration              = local.anvil_configuration
    anvil_instance_type              = local.anvil_instance_type
    virtual_network_resource_group   = local.network_resource_group_name
    virtual_network_name             = module.network.vnet_name
    virtual_network_ha_subnet_name   = module.network.cloud_filers_ha_subnet_name
    virtual_network_data_subnet_name = module.network.cloud_filers_subnet_name
    anvil_data_cluster_ip            = local.anvil_data_cluster_ip
    anvil_metadata_disk_storage_type = local.storage_account_type
    anvil_metadata_disk_size         = local.metadata_disk_size_gb

    module_depends_on = concat(module.network.module_depends_on_ids, [azurerm_resource_group.nfsfiler.id])
}

// the ephemeral filer
module "dsx" {
    source                           = "github.com/Azure/Avere/src/terraform/modules/hammerspace/dsx"
    resource_group_name              = azurerm_resource_group.nfsfiler.name
    location                         = azurerm_resource_group.nfsfiler.location
    hammerspace_image_id             = local.hammerspace_image_id
    unique_name                      = local.unique_name
    admin_username                   = local.vm_admin_username
    admin_password                   = local.vm_admin_password
    dsx_instance_count               = local.dsx_instance_count
    dsx_instance_type                = local.dsx_instance_type
    virtual_network_resource_group   = local.network_resource_group_name
    virtual_network_name             = module.network.vnet_name
    virtual_network_data_subnet_name = module.network.cloud_filers_subnet_name
    anvil_password                   = module.anvil.web_ui_password
    anvil_data_cluster_ip            = module.anvil.anvil_data_cluster_ip
    anvil_domain                     = module.anvil.anvil_domain
    dsx_data_disk_storage_type       = local.storage_account_type
    dsx_data_disk_size               = local.datadisk_size_gb

    module_depends_on = concat(module.network.module_depends_on_ids, [azurerm_resource_group.nfsfiler.id])
}

module "anvil_configure" {
    source                       = "github.com/Azure/Avere/src/terraform/modules/hammerspace/anvil-run-once-configure"
    anvil_arm_virtual_machine_id = length(module.anvil.arm_virtual_machine_ids) == 0 ? "" : module.anvil.arm_virtual_machine_ids[0]
    anvil_data_cluster_ip        = module.anvil.anvil_data_cluster_ip
    web_ui_password              = module.anvil.web_ui_password
    dsx_count                    = local.dsx_instance_count
    nfs_export_path              = local.hammerspace_filer_nfs_export_path
    anvil_hostname               = length(module.anvil.anvil_host_names) == 0 ? "" : module.anvil.anvil_host_names[0]

    module_depends_on = module.anvil.module_depends_on_ids
}

resource "azurerm_hpc_cache_nfs_target" "nfs_targets" {
  name                = "nfs_targets"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  cache_name          = azurerm_hpc_cache.hpc_cache.name
  target_host_name    = module.dsx.dsx_ip_addresses[0]
  usage_model         = local.usage_model
  namespace_junction {
    namespace_path = "/nfs1data"
    nfs_export     = local.hammerspace_filer_nfs_export_path
    target_path    = ""
  }

  depends_on = [module.anvil_configure.module_depends_on_id]
}

output "hammerspace_filer_addresses" {
  value = module.dsx.dsx_ip_addresses
}

output "hammerspace_webui_address" {
  value = module.anvil.anvil_data_cluster_ip
}

output "hammerspace_webui_address" {
  value = module.anvil.anvil_data_cluster_ip
}

output "hammerspace_filer_export" {
  value = local.hammerspace_filer_nfs_export_path
}

output "hammerspace_webui_username" {
    value = module.anvil.web_ui_username
}

output "hammerspace_webui_password" {
    value = module.anvil.web_ui_password
}

output "mount_addresses" {
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
}

output "export_namespace" {
  value = tolist(azurerm_hpc_cache_nfs_target.nfs_targets.namespace_junction)[0].namespace_path
}