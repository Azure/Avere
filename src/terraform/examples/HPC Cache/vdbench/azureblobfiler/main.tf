// customize the HPC Cache by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    
    // network details
    network_resource_group_name = "abanhowenetwork_resource_group"
    
    // hpc cache details
    hpc_cache_resource_group_name = "abanhowehpc_cache_resource_group"

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
    cache_name = "abanhoweuniquename"

    // usage model
    //    WRITE_AROUND
    //    READ_HEAVY_INFREQ
    //    WRITE_WORKLOAD_15
    usage_model = "WRITE_WORKLOAD_15"

    // storage details
    storage_resource_group_name = "abanhowestorage_resource_group"
    // create a globally unique name for the storage account
    storage_account_name = "abanhowe"
    avere_storage_container_name = "hpccache"
    nfs_export_path = "/blob_storage"

    // per the hpc cache documentation: https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-add-storage
    // customers who joined during the preview (before GA), will need to
    // swap the display names below.  This will manifest as the following
    // error:
    //       Error: A Service Principal with the Display Name "HPC Cache Resource Provider" was not found
    //
    hpc_cache_principal_name = "StorageCache Resource Provider"
    //hpc_cache_principal_name = "HPC Cache Resource Provider"

    // jumpbox related variables
    jumpbox_add_public_ip = true
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    //vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
    vm_ssh_key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8fhkh3jpHUQsrUIezFB5k4Rq9giJM8G1Cr0u2IRMiqG++nat5hbOr3gODpTA0h11q9bzb6nJtK7NtDzIHx+w3YNIVpcTGLiUEsfUbY53IHg7Nl/p3/gkST3g0R6BSL7Hg45SfyvpH7kwY30MoVHG/6P3go4SKlYoHXlgaaNr3fMwUTIeE9ofvyS3fcr6xxlsoB6luKuEs50h0NGsE4QEnbfSY4Yd/C1ucc3mEw+QFXBIsENHfHfZYrLNHm2L8MXYVmAH8k//5sFs4Migln9GiUgEQUT6uOjowsZyXBbXwfT11og+syPkAq4eqjiC76r0w6faVihdBYVoc/UcyupgH azureuser@linuxvm"

    # download the latest vdbench from https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html
    # and upload to an azure storage blob and put the URL below
    vdbench_url = "https://vdbench.blob.core.windows.net/vdbench/vdbench50407.zip?st=2020-03-25T10%3A03%3A55Z&se=2041-03-26T10%3A03%3A00Z&sp=rl&sv=2018-03-28&sr=b&sig=vjbkX3VtSj8dVxJG0CRE8RK6nEHwqf7nXr0oe8KHqGM%3D"
    
    // vmss details
    vmss_resource_group_name = "abanhowevmss_rg"
    unique_name = "abanhoweuniquename"
    vm_count = 12
    vmss_size = "Standard_DS2_v2"
    mount_target = "/data"
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
  depends_on = [module.network]
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

  depends_on = [azurerm_storage_container.blob_container]
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

  depends_on           = [null_resource.delay]
}

module "jumpbox" {
    source = "github.com/Azure/Avere/src/terraform/modules/jumpbox"
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

// the vdbench module
module "vdbench_configure" {
    source = "github.com/Azure/Avere/src/terraform/modules/vdbench_config"

    node_address = module.jumpbox.jumpbox_address
    admin_username = module.jumpbox.jumpbox_username
    admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    nfs_address = azurerm_hpc_cache.hpc_cache.mount_addresses[0]
    nfs_export_path = azurerm_hpc_cache_blob_target.blob_target1.namespace_path
    vdbench_url = local.vdbench_url
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
    nfs_export_path = azurerm_hpc_cache_blob_target.blob_target1.namespace_path
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
  value = azurerm_hpc_cache.hpc_cache.mount_addresses
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