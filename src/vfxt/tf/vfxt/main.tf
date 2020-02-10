resource "avere_vfxt" "vfxt" {
    controller_address = "IPADDR"
    controller_admin_username = "USERNAME"
    resource_group = "rg"
    location = "eastus"
    network_resource_group = "render-net"
    network_name = "render-net"
    subnet_name = "avere"
    vfxt_cluster_name = "vfxt"
    vfxt_admin_password = "PASSWORD"
    vfxt_node_count = 3
}