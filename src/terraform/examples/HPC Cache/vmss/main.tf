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
    nfs_export_path = "/nfs1data"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    // jumpbox variable
    jumpbox_add_public_ip = true
    ssh_port = 22
        
    // vmss details
    vmss_resource_group_name = "vmss_rg"
    unique_name = "uniquename"
    vm_count = 2
    vmss_size = "Standard_DS2_v2"
    mount_target = "/data"

    // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
    open_external_ports = [local.ssh_port,3389]
    // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
    // or if accessing from cloud shell, put "AzureCloud"
    open_external_sources = ["*"]
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

    open_external_ports   = local.open_external_ports
    open_external_sources = local.open_external_sources
}

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
  // the depends on is necessary for destroy.  Due to the
  // limitation of the template deployment, the only
  // way to destroy template resources is to destroy
  // the resource group
  depends_on = [module.network.module_depends_on_ids]
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
module "nasfiler1" {
    source = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
    resource_group_name = azurerm_resource_group.nfsfiler.name
    location = azurerm_resource_group.nfsfiler.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    vm_size = "Standard_D2s_v3"
    unique_name = "nasfiler1"

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.cloud_filers_subnet_name
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
    source = "github.com/Azure/Avere/src/terraform/modules/jumpbox"
    resource_group_name = azurerm_resource_group.hpc_cache_rg.name
    location = local.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.jumpbox_add_public_ip
    ssh_port = local.ssh_port

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.jumpbox_subnet_name

    module_depends_on = [azurerm_resource_group.hpc_cache_rg.id]
}

// the vmss config module to install the round robin mount
module "vmss_configure" {
    source = "github.com/Azure/Avere/src/terraform/modules/vmss_config"

    node_address = module.jumpbox.jumpbox_address
    admin_username = module.jumpbox.jumpbox_username
    admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
    ssh_port = local.ssh_port
    ssh_key_data = local.vm_ssh_key_data
    nfs_address = azurerm_hpc_cache.hpc_cache.mount_addresses[0]
    nfs_export_path = tolist(azurerm_hpc_cache_nfs_target.nfs_targets.namespace_junction)[0].namespace_path

    module_depends_on = [azurerm_hpc_cache_nfs_target.nfs_targets.id, module.jumpbox.module_depends_on_id]
}

// the VMSS module
module "vmss" {
    source = "github.com/Azure/Avere/src/terraform/modules/vmss_mountable"

    resource_group_name = local.vmss_resource_group_name
    location = local.location
    admin_username =local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    unique_name = local.unique_name
    vm_count = local.vm_count
    vm_size = local.vmss_size
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.render_clients1_subnet_name
    mount_target = local.mount_target
    nfs_export_addresses = azurerm_hpc_cache.hpc_cache.mount_addresses
    nfs_export_path = local.nfs_export_path
    bootstrap_script_path = module.vmss_configure.bootstrap_script_path
    module_depends_on = [module.vmss_configure.module_depends_on_id]
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

output "export_namespace" {
  value = tolist(azurerm_hpc_cache_nfs_target.nfs_targets.namespace_junction)[0].namespace_path
}