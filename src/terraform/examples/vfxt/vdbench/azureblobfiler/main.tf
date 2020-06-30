// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    network_resource_group_name   = "vdbench_network_rg"
    storage_resource_group_name   = "vdbench_storage_rg"
    vfxt_resource_group_name      = "vdbench_vfxt_rg"
    vmss_resource_group_name      = "vdbench_vmss_rg"
    
    vm_admin_username = "azureuser"
    // the vdbench example requires an ssh key
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
    ssh_port = 22
    
    // storage details
    storage_account_name = ""
    avere_storage_container_name = "vdbench"
    nfs_export_path = "/vdbench"
    
    // vfxt details
    // if you are running a locked down network, set controller_add_public_ip to false
    controller_add_public_ip = true
    vfxt_cluster_name = "vfxt"
    vfxt_cluster_password = "VFXT_PASSWORD"
    vfxt_ssh_key_data = local.vm_ssh_key_data

    # download the latest vdbench from https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html
    # and upload to an azure storage blob and put the URL below
    vdbench_url = ""

    // vmss details
    unique_name = "vmss"
    vm_count = 12
    vmss_size = "Standard_D2s_v3"
    mount_target = "/data"

    alternative_resource_groups = [local.storage_resource_group_name]
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
    source = "github.com/Azure/Avere/src/terraform/modules/render_network"
    resource_group_name = local.network_resource_group_name
    location = local.location

    open_external_ports   = local.open_external_ports
    open_external_sources = local.open_external_sources
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
  network_rules {
      virtual_network_subnet_ids = [
          module.network.cloud_cache_subnet_id,
          // need for the controller to create the container
          module.network.jumpbox_subnet_id,
      ]
      default_action = "Deny"
  }
  // if the nsg associations do not complete before the storage account
  // create is started, it will fail with "subnet updating"
  depends_on = [module.network]
}

// the vfxt controller
module "vfxtcontroller" {
    source = "github.com/Azure/Avere/src/terraform/modules/controller"
    resource_group_name = local.vfxt_resource_group_name
    location = local.location
    admin_username = local.vm_admin_username
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.controller_add_public_ip
    alternative_resource_groups = local.alternative_resource_groups
    ssh_port = local.ssh_port
    
    // network details
    virtual_network_resource_group = module.network.vnet_resource_group
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.jumpbox_subnet_name

    module_depends_on = [module.network.vnet_id]
}

// the vfxt
resource "avere_vfxt" "vfxt" {
    controller_address = module.vfxtcontroller.controller_address
    controller_admin_username = module.vfxtcontroller.controller_username
    controller_ssh_port = local.ssh_port
    // terraform is not creating the implicit dependency on the controller module
    // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
    // to work around, add the explicit dependency
    depends_on = [module.vfxtcontroller]
    
    location = local.location
    azure_resource_group = local.vfxt_resource_group_name
    azure_network_resource_group = module.network.vnet_resource_group
    azure_network_name = module.network.vnet_name
    azure_subnet_name = module.network.cloud_cache_subnet_name
    vfxt_cluster_name = local.vfxt_cluster_name
    vfxt_admin_password = local.vfxt_cluster_password
    vfxt_ssh_key_data = local.vfxt_ssh_key_data
    vfxt_node_count = 3

    azure_storage_filer {
        account_name = azurerm_storage_account.storage.name
        container_name = local.avere_storage_container_name
        custom_settings = []
        junction_namespace_path = local.nfs_export_path
    }
} 

// the vdbench module
module "vdbench_configure" {
    source = "github.com/Azure/Avere/src/terraform/modules/vdbench_config"

    node_address = module.vfxtcontroller.controller_address
    admin_username = module.vfxtcontroller.controller_username
    ssh_key_data = local.vm_ssh_key_data
    nfs_address = tolist(avere_vfxt.vfxt.vserver_ip_addresses)[0]
    nfs_export_path = local.nfs_export_path
    vdbench_url = local.vdbench_url

    module_depends_on = [avere_vfxt.vfxt]
}

// the VMSS module
module "vmss" {
    source = "github.com/Azure/Avere/src/terraform/modules/vmss_mountable"

    resource_group_name = local.vmss_resource_group_name
    location = local.location
    admin_username = module.vfxtcontroller.controller_username
    ssh_key_data = local.vm_ssh_key_data
    unique_name = local.unique_name
    vm_count = local.vm_count
    vm_size = local.vmss_size
    virtual_network_resource_group = module.network.vnet_resource_group
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.render_clients1_subnet_name
    mount_target = local.mount_target
    nfs_export_addresses = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
    nfs_export_path = local.nfs_export_path
    bootstrap_script_path = module.vdbench_configure.bootstrap_script_path
    module_depends_on = [module.vdbench_configure.module_depends_on_id]
    
}

output "controller_username" {
  value = module.vfxtcontroller.controller_username
}

output "controller_address" {
  value = module.vfxtcontroller.controller_address
}

output "ssh_command_with_avere_tunnel" {
    value = "ssh -p ${local.ssh_port} -L8443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
}

output "management_ip" {
    value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
    value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
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