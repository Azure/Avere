// customize the HPC Cache by editing the following local variables
locals {
  // the region of the deployment
  location                      = "eastus"
  hpc_cache_resource_group_name = "vdbench_hpccache_rg"
  network_resource_group_name   = "vdbench_network_rg"
  storage_resource_group_name   = "vdbench_storage_rg"
  vmss_resource_group_name      = "vdbench_vmss_rg"

  // HPC Cache Throughput SKU - allowed values for throughput (GB/s) of the cache
  //  Standard_2G
  //  Standard_4G
  //  Standard_8G
  //  Standard_L4_5G 
  //  Standard_L9G 
  //  Standard_L16G 
  cache_throughput = "Standard_2G"

  // HPC Cache Size - allowed sizes (GBs) for the cache
  //   3072
  //   6144
  //  12288
  //  24576
  //  49152
  cache_size = 12288

  // unique name for cache
  cache_name = "hpccache"

  // usage model
  //  WRITE_AROUND
  //  READ_HEAVY_INFREQ
  //  WRITE_WORKLOAD_15
  usage_model = "WRITE_WORKLOAD_15"

  // create a globally unique name for the storage account
  storage_account_name         = ""
  avere_storage_container_name = "vdbench"
  nfs_export_path              = "/vdbench"

  // per the hpc cache documentation: https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-add-storage
  // customers who joined during the preview (before GA), will need to
  // swap the display names below.  This will manifest as the following
  // error:
  //       Error: A Service Principal with the Display Name "HPC Cache Resource Provider" was not found
  //
  //hpc_cache_principal_name = "StorageCache Resource Provider"
  hpc_cache_principal_name = "HPC Cache Resource Provider"

  // jumpbox related variables
  jumpbox_add_public_ip = true
  ssh_port              = 22

  vm_admin_username = "azureuser"
  // the vdbench example requires an ssh key
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  # download the latest vdbench from https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html
  # and upload to an azure storage blob and put the URL below
  vdbench_url = ""

  // vmss details
  unique_name  = "vmss"
  vm_count     = 12
  vmss_size    = "Standard_D2s_v3"
  mount_target = "/data"

  // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
  open_external_ports = [local.ssh_port, 3389]
  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  open_external_sources = ["*"]
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

resource "azurerm_resource_group" "hpc_cache_rg" {
  name     = local.hpc_cache_resource_group_name
  location = local.location
}

resource "azurerm_resource_group" "storage" {
  name     = local.storage_resource_group_name
  location = local.location
}

// the render network
module "network" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_resource_group_name
  location            = local.location

  open_external_ports   = local.open_external_ports
  open_external_sources = local.open_external_sources
}

resource "azurerm_hpc_cache" "hpc_cache" {
  name                = local.cache_name
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  cache_size_in_gb    = local.cache_size
  subnet_id           = module.network.cloud_cache_subnet_id
  sku_name            = local.cache_throughput
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
  namespace_path       = local.nfs_export_path

  depends_on = [
    null_resource.delay,
  ]
}

module "jumpbox" {
  source              = "github.com/Azure/Avere/src/terraform/modules/jumpbox"
  resource_group_name = azurerm_resource_group.hpc_cache_rg.name
  location            = azurerm_resource_group.hpc_cache_rg.location
  admin_username      = local.vm_admin_username
  ssh_key_data        = local.vm_ssh_key_data
  add_public_ip       = local.jumpbox_add_public_ip
  ssh_port            = local.ssh_port

  // network details
  virtual_network_resource_group = module.network.vnet_resource_group
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.jumpbox_subnet_name

  depends_on = [
    azurerm_resource_group.hpc_cache_rg,
    module.network,
  ]
}

// the vdbench module
module "vdbench_configure" {
  source = "github.com/Azure/Avere/src/terraform/modules/vdbench_config"

  node_address    = module.jumpbox.jumpbox_address
  admin_username  = module.jumpbox.jumpbox_username
  ssh_key_data    = local.vm_ssh_key_data
  nfs_address     = azurerm_hpc_cache.hpc_cache.mount_addresses[0]
  nfs_export_path = azurerm_hpc_cache_blob_target.blob_target1.namespace_path
  vdbench_url     = local.vdbench_url
  ssh_port        = local.ssh_port

  depends_on = [
    azurerm_hpc_cache_blob_target.blob_target1,
    azurerm_hpc_cache.hpc_cache,
    module.jumpbox,
  ]
}

// the VMSS module
module "vmss" {
  source = "github.com/Azure/Avere/src/terraform/modules/vmss_mountable"

  resource_group_name            = local.vmss_resource_group_name
  location                       = local.location
  admin_username                 = local.vm_admin_username
  ssh_key_data                   = local.vm_ssh_key_data
  unique_name                    = local.unique_name
  vm_count                       = local.vm_count
  vm_size                        = local.vmss_size
  virtual_network_resource_group = module.network.vnet_resource_group
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.render_clients1_subnet_name
  mount_target                   = local.mount_target
  nfs_export_addresses           = azurerm_hpc_cache.hpc_cache.mount_addresses
  nfs_export_path                = azurerm_hpc_cache_blob_target.blob_target1.namespace_path
  bootstrap_script_path          = module.vdbench_configure.bootstrap_script_path

  depends_on = [
    module.vdbench_configure,
    azurerm_hpc_cache_blob_target.blob_target1,
    module.network,
  ]
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

output "ssh_port" {
  value = local.ssh_port
}

output "export_namespace" {
  value = azurerm_hpc_cache_blob_target.blob_target1.namespace_path
}

output "vmss_id" {
  value = module.vmss.vmss_id
}

output "vmss_resource_group" {
  value = module.vmss.vmss_resource_group
}

output "vmss_name" {
  value = module.vmss.vmss_name
}

output "vmss_addresses_command" {
  // local-exec doesn't return output, and the only way to 
  // try to get the output is follow advice from https://stackoverflow.com/questions/49136537/obtain-ip-of-internal-load-balancer-in-app-service-environment/49436100#49436100
  // in the meantime just provide the az cli command to
  // the customer
  value = "az vmss nic list -g ${module.vmss.vmss_resource_group} --vmss-name ${module.vmss.vmss_name} --query \"[].ipConfigurations[].privateIpAddress\""
}
