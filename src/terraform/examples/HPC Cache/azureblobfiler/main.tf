// customize the HPC Cache by editing the following local variables
locals {
  // the region of the deployment
  location = "eastus"

  // network details
  network_resource_group_name = "network_resource_group"

  // hpc cache details
  hpc_cache_resource_group_name = "hpc_cache_resource_group"

  // HPC Cache Throughput SKU - 3 allowed values for throughput (GB/s) of the cache
  //  Standard_2G
  //  Standard_4G
  //  Standard_8G
  cache_throughput = "Standard_2G"

  // HPC Cache Size - 5 allowed sizes (GBs) for the cache
  //   3072
  //   6144
  //  12288
  //  24576
  //  49152
  cache_size = 12288

  // unique name for cache
  cache_name = "uniquename"

  // usage model
  //  WRITE_AROUND
  //  READ_HEAVY_INFREQ
  //  WRITE_WORKLOAD_15
  usage_model = "READ_HEAVY_INFREQ"

  // storage details
  storage_resource_group_name = "storage_resource_group"
  // create a globally unique name for the storage account
  storage_account_name         = ""
  avere_storage_container_name = "hpccache"

  // per the hpc cache documentation: https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-add-storage
  // customers who joined during the preview (before GA), will need to
  // swap the display names below.  This will manifest as the following
  // error:
  //       Error: A Service Principal with the Display Name "HPC Cache Resource Provider" was not found
  //
  //hpc_cache_principal_name = "StorageCache Resource Provider"
  hpc_cache_principal_name = "HPC Cache Resource Provider"
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
}

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
  // the depends on is necessary for destroy.  Due to the
  // limitation of the template deployment, the only
  // way to destroy template resources is to destroy
  // the resource group
  depends_on = [
    module.network,
  ]
}

resource "azurerm_hpc_cache" "hpc_cache" {
  name                = local.cache_name
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  cache_size_in_gb    = local.cache_size
  subnet_id           = module.network.cloud_cache_subnet_id
  sku_name            = local.cache_throughput
}

resource "azurerm_resource_group" "storage" {
  name     = local.storage_resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  // if the nsg associations do not complete before the storage account
  // create is started, it will fail with "subnet updating"
  depends_on = [
    module.network,
  ]
}

resource "azurerm_storage_container" "blob_container" {
  name                 = local.avere_storage_container_name
  storage_account_name = azurerm_storage_account.storage.name
}

/*
// Azure Storage ACLs on the subnet are not compatible with the azurerm_storage_container blob_container
resource "azurerm_storage_account_network_rules" "storage_acls" {
  resource_group_name  = azurerm_resource_group.storage.name
  storage_account_name = azurerm_storage_account.storage.name
  
  virtual_network_subnet_ids = [
    module.network.cloud_cache_subnet_id,
    // need for the controller to create the container
    module.network.jumpbox_subnet_id,
  ]
  default_action = "Deny"

  depends_on = [
    azurerm_storage_container.blob_container,
  ]
}*/

data "azuread_service_principal" "hpc_cache_sp" {
  display_name = local.hpc_cache_principal_name
}

resource "azurerm_role_assignment" "storage_account_contrib" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azuread_service_principal.hpc_cache_sp.object_id
}

resource "azurerm_role_assignment" "storage_blob_data_contrib" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_service_principal.hpc_cache_sp.object_id
}

// delay in linux or windows 180s for the role assignments to propagate.
// there is similar guidance in per the hpc cache documentation: https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-add-storage
resource "null_resource" "delay" {
  depends_on = [
    azurerm_role_assignment.storage_account_contrib,
    azurerm_role_assignment.storage_blob_data_contrib,
  ]

  provisioner "local-exec" {
    command    = "sleep 180 || ping -n 180 127.0.0.1 > nul"
    on_failure = continue
  }
}

resource "azurerm_hpc_cache_blob_target" "blob_target1" {
  name                 = "azureblobtarget"
  resource_group_name  = azurerm_resource_group.hpc_cache_rg.name
  cache_name           = azurerm_hpc_cache.hpc_cache.name
  storage_container_id = azurerm_storage_container.blob_container.resource_manager_id
  namespace_path       = "/blob_storage"

  depends_on = [
    null_resource.delay,
  ]
}

output "mount_addresses" {
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
}

output "export_namespace" {
  value = azurerm_hpc_cache_blob_target.blob_target1.namespace_path
}
