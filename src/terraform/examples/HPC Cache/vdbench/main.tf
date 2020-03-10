// customize the HPC Cache by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    
    // network details
    network_resource_group_name = "network_resource_group"
    
    // vfxt details
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
    usage_model = "WRITE_WORKLOAD_15"

    // nfs filer related variables
    filer_resource_group_name = "filer_resource_group"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    // jumpbox variable
    jumpbox_add_public_ip = true

    # download the latest vdbench from https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html
    # and upload to an azure storage blob and put the URL below
    vdbench_url = ""
    
    // vmss details
    vmss_resource_group_name = "vmss_rg"
    unique_name = "uniquename"
    vm_count = 2
    vmss_size = "Standard_DS2_v2"
    mount_target = "/data"
}

provider "azurerm" {
    version = "~>2.0.0"
    features {}
}

// the render network
module "network" {
    source              = "../../../modules/render_network"
    resource_group_name = local.network_resource_group_name
    location            = local.location
}

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
  // the depends on is necessary for destroy.  Due to the
  // limitation of the template deployment, the only
  // way to destroy template resources is to destroy
  // the resource group
  depends_on = [module.network]
}

data "azurerm_subnet" "vnet" {
  name                 = module.network.cloud_cache_subnet_name
  virtual_network_name = module.network.vnet_name
  resource_group_name  = local.network_resource_group_name
}

// load the HPC Cache Template, with the necessary variables
locals {
    arm_template = templatefile("${path.module}/../hpc_cache.json",
    {
        uniquename   = local.cache_name,
        location     = local.location,
        hpccsku      = local.cache_throughput,
        subnetid     = data.azurerm_subnet.vnet.id,
        hpccachesize = local.cache_size
    })
}

// HPC cache is currently deployed using azurerm_template_deployment as described in
// https://www.terraform.io/docs/providers/azurerm/r/template_deployment.html. 
// The only way to destroy a template deployment is to destroy the associated
// RG, so keep each template unique to its RG. 
resource "azurerm_template_deployment" "storage_cache" {
  name                = "hpc_cache"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  deployment_mode     = "Incremental"
  template_body       = local.arm_template
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.location
}

// the ephemeral filer
module "nasfiler1" {
    source = "../../../modules/nfs_filer"
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

// load the Storage Target Template, with the necessary variables
locals {
    nfs_export_path = "/nfs1data"
    storage_target_1_template = templatefile("${path.module}/../storage_target.json",
    {
        uniquename              = local.cache_name,
        uniquestoragetargetname = "storage_target_1",
        location                = local.location,
        nfsaddress              = module.nasfiler1.primary_ip,
        usagemodel              = local.usage_model,
        namespacepath_j1        = local.nfs_export_path,
        nfsexport_j1            = module.nasfiler1.core_filer_export,
        targetpath_j1           = ""
    })
}

resource "azurerm_template_deployment" "storage_target1" {
  name                = "storage_target_1"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  deployment_mode     = "Incremental"
  template_body       = local.storage_target_1_template

  depends_on = [
    azurerm_template_deployment.storage_cache, // add after cache created
    module.nasfiler1
  ]
}

module "jumpbox" {
    source = "../../../modules/jumpbox"
    resource_group_name = azurerm_resource_group.hpc_cache_rg.name
    location = local.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.jumpbox_add_public_ip

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.jumpbox_subnet_name
}

locals {
  mount_addresses = split(",", replace(trim(azurerm_template_deployment.storage_cache.outputs["mountAddresses"],"]["),"\"",""))
}

// the vdbench module
module "vdbench_configure" {
    source = "../../../modules/vdbench_config"

    node_address = module.jumpbox.jumpbox_address
    admin_username = module.jumpbox.jumpbox_username
    admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    nfs_address = local.mount_addresses[0]
    nfs_export_path = azurerm_template_deployment.storage_target1.outputs["namespacePath"]
    vdbench_url = local.vdbench_url
}

// the VMSS module
module "vmss" {
    source = "../../../modules/vmss_mountable"

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
    nfs_export_addresses = local.mount_addresses
    nfs_export_path = local.nfs_export_path
    bootstrap_script_path = module.vdbench_configure.bootstrap_script_path
    vmss_depends_on = module.vdbench_configure.bootstrap_script_path
}

output "jumpbox_username" {
  value = module.jumpbox.jumpbox_username
}

output "jumpbox_address" {
  value = module.jumpbox.jumpbox_address
}

output "mount_addresses" {
  value = local.mount_addresses
}

output "export_namespace" {
  value = azurerm_template_deployment.storage_target1.outputs["namespacePath"]
}