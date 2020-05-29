// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    // network details
    network_resource_group_name = "network_resource_group"
    
    // nfs filer details
    filer_resource_group_name = "filer_resource_group"
    
    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
    // if you are running a locked down network, set controller_add_public_ip to false
    controller_add_public_ip = true
    vfxt_cluster_name = "vfxt"
    vfxt_cluster_password = "VFXT_PASSWORD"
    // vfxt cache polies
    //  "Clients Bypassing the Cluster"
    //  "Read Caching"
    //  "Read and Write Caching"
    //  "Full Caching"
    //  "Transitioning Clients Before or After a Migration"
    //  "Isolated Cloud Workstation"
    //  "Collaborating Cloud Workstation"
    cache_policy = "Isolated Cloud Workstation"
    
    // advanced scenario: vfxt and controller image ids, leave this null, unless not using default marketplace
    controller_image_id = null
    vfxt_image_id       = null
    // advanced scenario: put the custom image resource group here
    alternative_resource_groups = []
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

// the vfxt controller
module "vfxtcontroller" {
    source = "github.com/Azure/Avere/src/terraform/modules/controller"
    resource_group_name = local.vfxt_resource_group_name
    location = local.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.controller_add_public_ip
    image_id = local.controller_image_id
    alternative_resource_groups = local.alternative_resource_groups

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.jumpbox_subnet_name

    module_depends_on  = [module.network.vnet_id]
}

// the vfxt
resource "avere_vfxt" "vfxt" {
    controller_address = module.vfxtcontroller.controller_address
    controller_admin_username = module.vfxtcontroller.controller_username
    // ssh key takes precedence over controller password
    controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
    // terraform is not creating the implicit dependency on the controller module
    // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
    // to work around, add the explicit dependency
    depends_on = [module.vfxtcontroller]
    
    location = local.location
    azure_resource_group = local.vfxt_resource_group_name
    azure_network_resource_group = local.network_resource_group_name
    azure_network_name = module.network.vnet_name
    azure_subnet_name = module.network.cloud_cache_subnet_name
    vfxt_cluster_name = local.vfxt_cluster_name
    vfxt_admin_password = local.vfxt_cluster_password
    vfxt_node_count = 3
    image_id = local.vfxt_image_id

    core_filer {
        name = "nfs1"
        fqdn_or_primary_ip = module.nasfiler1.primary_ip
        cache_policy = local.cache_policy
        junction {
            namespace_path = "/nfs1data"
            core_filer_export = module.nasfiler1.core_filer_export
        }
        /* add additional junctions by adding another junction block shown below
        junction {
            namespace_path = "/nfsdata2"
            core_filer_export = "/data2"
        }
        */
    }
} 

output "controller_username" {
  value = module.vfxtcontroller.controller_username
}

output "controller_address" {
  value = module.vfxtcontroller.controller_address
}

output "ssh_command_with_avere_tunnel" {
    value = "ssh -L443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
}

output "management_ip" {
    value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
    value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}