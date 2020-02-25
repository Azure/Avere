// customize the simple VM by adjusting the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "PASSWORD"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    // network details
    network_resource_group_name = "network_resource_group"
    
    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
    // if you are running a locked down network, set controller_add_public_ip to false
    controller_add_public_ip = true
    vfxt_cluster_name = "vfxt"
    vfxt_cluster_password = "VFXT_PASSWORD"
}

// the render network
module "network" {
    source = "../../../modules/render_network"
    resource_group_name = local.network_resource_group_name
    location = local.location
}

// the vfxt controller
module "vfxtcontroller" {
    source = "../../../modules/controller"
    resource_group_name = local.vfxt_resource_group_name
    location = local.location
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.controller_add_public_ip

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.cloud_cache_subnet_name
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
} 
