resource "avere_vfxt" "vfxt" {
    controller_address = "CONTROLLER_ADDRESS"
    controller_admin_username = "azureuser"
    resource_group = "RESOURCE_GROUP"
    location = "LOCATION"
    network_resource_group = "NETWORK_RESOURCE_GROUP"
    network_name = "NETWORK_NAME"
    subnet_name = "SUBNET_NAME"
    vfxt_cluster_name = "vfxt"
    vfxt_admin_password = "PASSWORD"
    vfxt_node_count = 3
}