// customize the simple VM by editing the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    
    // network details
    virtual_network_resource_group = "network_resource_group"
    virtual_network_name = "rendervnet"
    vfxt_network_subnet_name = "cloud_cache"
    
    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
    vfxt_cluster_name = "vfxt"
    vfxt_cluster_password = "VFXT_PASSWORD"
    
    // filer details
    filer_address = ""
    filer_export = "/data"
    
    // vfxt cache polies
    //  "Clients Bypassing the Cluster"
    //  "Read Caching"
    //  "Read and Write Caching"
    //  "Full Caching"
    //  "Transitioning Clients Before or After a Migration"
    cache_policy = "Clients Bypassing the Cluster"
}

resource "avere_vfxt" "vfxt" {
    run_local = true

    location = local.location
    azure_resource_group = local.vfxt_resource_group_name
    azure_network_resource_group = local.virtual_network_resource_group
    azure_network_name = local.virtual_network_name
    azure_subnet_name = local.vfxt_network_subnet_name
    vfxt_cluster_name = local.vfxt_cluster_name
    vfxt_admin_password = local.vfxt_cluster_password
    vfxt_node_count = 3

    core_filer {
        name = "nfs1"
        fqdn_or_primary_ip = local.filer_address
        cache_policy = local.cache_policy
        junction {
            namespace_path = "/nfs1data"
            core_filer_export = local.filer_export
        }
    }
}

output "management_ip" {
    value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
    value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}
