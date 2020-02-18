// customize the simple VM by adjusting the following local variables
locals {
    // region
    location = "eastus"

    // network details
    network_resource_group_name = "network_resource_group"
    
    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
    add_public_ip = true
    admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    admin_password = "PASSWORD"
    ssh_key_data = null //"ssh-rsa AAAAB3...."
    cluster_name = "vfxt"
    cluster_password = "VFXT_PASSWORD"
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
    admin_password = local.admin_password
    ssh_key_data = local.ssh_key_data
    add_public_ip = local.add_public_ip

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.cloud_cache_subnet_name
}

// the vfxt
resource "avere_vfxt" "vfxt" {
    controller_address = module.vfxtcontroller.controller_address
    controller_admin_username = module.vfxtcontroller.controller_username
    controller_admin_password = local.admin_password
    resource_group = local.vfxt_resource_group_name
    location = local.location
    network_resource_group = local.network_resource_group_name
    network_name = module.network.vnet_name
    subnet_name = module.network.cloud_cache_subnet_name
    vfxt_cluster_name = local.cluster_name
    vfxt_admin_password = local.cluster_password
    vfxt_node_count = 3
}