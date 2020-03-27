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
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
   
}

provider "azurerm" {
    version = "~>2.3.0"
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
  // the depends on is necessary for destroy.  Due to the
  // limitation of the template deployment, the only
  // way to destroy template resources is to destroy
  // the resource group
  depends_on = [module.network]
}

resource "azurerm_hpc_cache" "hpc_cache" {
  name                = local.cache_name
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  cache_size_in_gb    = local.cache_size
  subnet_id           = module.network.cloud_filers_subnet_id
  sku_name            = "Standard_2G"
}

// load the Storage Target Template, with the necessary variables
locals {
    storage_target_1_template = templatefile("${path.module}/../storage_target.json",
    {
        uniquename              = local.cache_name,
        uniquestoragetargetname = "storage_target_1",
        location                = local.location,
        nfsaddress              = module.nasfiler1.primary_ip,
        usagemodel              = local.usage_model,
        namespacepath_j1        = "/nfs1data",
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
    azurerm_hpc_cache.hpc_cache,, // add after cache created
    module.nasfiler1
  ]
}

// the ephemeral filer
module "nasfiler2" {
    source = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
    resource_group_name = azurerm_resource_group.nfsfiler.name
    location = azurerm_resource_group.nfsfiler.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    vm_size = "Standard_D2s_v3"
    unique_name = "nasfiler2"

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.cloud_filers_subnet_name
}

// load the Storage Target Template, with the necessary variables
locals {
    storage_target_2_template = templatefile("${path.module}/../storage_target.json",
    {
        uniquename              = local.cache_name,
        uniquestoragetargetname = "storage_target_2",
        location                = azurerm_resource_group.hpc_cache_rg.location,
        nfsaddress              = module.nasfiler2.primary_ip,
        usagemodel              = local.usage_model,
        namespacepath_j1        = "/nfs2data",
        nfsexport_j1            = module.nasfiler2.core_filer_export,
        targetpath_j1           = ""
    })
}

resource "azurerm_template_deployment" "storage_target2" {
  name                = "storage_target_2"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  deployment_mode     = "Incremental"
  template_body       = local.storage_target_2_template

  depends_on = [
    azurerm_template_deployment.storage_target1, // add after storage target1
    module.nasfiler2
  ]
}

// the ephemeral filer
module "nasfiler3" {
    source = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
    resource_group_name = azurerm_resource_group.nfsfiler.name
    location = azurerm_resource_group.nfsfiler.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    vm_size = "Standard_D2s_v3"
    unique_name = "nasfiler3"

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.cloud_filers_subnet_name
}

// load the Storage Target Template, with the necessary variables
locals {
    storage_target_3_template = templatefile("${path.module}/../storage_target.json",
    {
        uniquename              = local.cache_name,
        uniquestoragetargetname = "storage_target_3",
        location                = azurerm_resource_group.hpc_cache_rg.location,
        nfsaddress              = module.nasfiler3.primary_ip,
        usagemodel              = local.usage_model,
        namespacepath_j1        = "/nfs3data",
        nfsexport_j1            = module.nasfiler3.core_filer_export,
        targetpath_j1           = ""
    })
}

resource "azurerm_template_deployment" "storage_target3" {
  name                = "storage_target_3"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  deployment_mode     = "Incremental"
  template_body       = local.storage_target_3_template

  depends_on = [
    azurerm_template_deployment.storage_target2, // add after storage target2
    module.nasfiler3
  ]
}

output "mount_addresses" {
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
}

output "export_namespace_1" {
  value = azurerm_template_deployment.storage_target1.outputs["namespacePath"]
}

output "export_namespace_2" {
  value = azurerm_template_deployment.storage_target2.outputs["namespacePath"]
}

output "export_namespace_3" {
  value = azurerm_template_deployment.storage_target3.outputs["namespacePath"]
}