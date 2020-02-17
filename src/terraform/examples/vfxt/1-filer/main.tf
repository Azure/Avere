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
    
    core_filer {
        name = "nfs1"
        fqdn_or_primary_ip = "10.4.1.4"
        cache_policy = "Clients Bypassing the Cluster"
        junction {
            namespace_path = "/nfs1data"
            core_filer_export = "/data"
        }
        /* add additional junctions by adding another junction block shown below
        junction {
            namespace_path = "/nfsdata2"
            core_filer_export = "/data2"
        }
        */
    }
}