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
}

provider "azurerm" {
    version = "~>2.1.0"
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

locals {
  mount_addresses = split(",", replace(trim(azurerm_template_deployment.storage_cache.outputs["mountAddresses"],"]["),"\"",""))
}

output "mount_addresses" {
  value = local.mount_addresses
}