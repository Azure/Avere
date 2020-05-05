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
    virtual_network_resource_group = "network_resource_group"
    virtual_network_name = "rendervnet"
    controller_network_subnet_name = "jumpbox"
    vfxt_network_subnet_name = "cloud_cache"
    
    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
    // if you are running a locked down network, set controller_add_public_ip to false, but ensure
    // you have access to the subnet
    controller_add_public_ip = true
    vfxt_cluster_name = "vfxt"
    vfxt_cluster_password = "ReplacePassword$"
    // vfxt cache polies
    //  "Clients Bypassing the Cluster"
    //  "Read Caching"
    //  "Read and Write Caching"
    //  "Full Caching"
    //  "Transitioning Clients Before or After a Migration"
    cache_policy = "Clients Bypassing the Cluster"

    // the proxy used by vfxt.py for cluster stand-up and scale-up / scale-down
    proxy_uri = null
    // the proxy used by the running vfxt cluster
    cluster_proxy_uri = null

    // advanced scenario: vfxt and controller image ids, leave this null, unless not using default marketplace
    controller_image_id = null
    vfxt_image_id       = null
    // advanced scenario: put the custom image resource group here
    alternative_resource_groups = []
}

provider "azurerm" {
    version = "~>2.8.0"
    features {}
}

// the vfxt controller
module "vfxtcontroller" {
    source = "github.com/Azure/Avere/src/terraform/modules/controller"
    create_resource_group = false
    resource_group_name = local.vfxt_resource_group_name
    location = local.location
    admin_username = local.vm_admin_username
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    add_public_ip = local.controller_add_public_ip
    image_id = local.controller_image_id
    alternative_resource_groups = local.alternative_resource_groups

    // network details
    virtual_network_resource_group = local.virtual_network_resource_group
    virtual_network_name = local.virtual_network_name
    virtual_network_subnet_name = local.controller_network_subnet_name
}

resource "avere_vfxt" "vfxt" {
    controller_address = module.vfxtcontroller.controller_address
    controller_admin_username = module.vfxtcontroller.controller_username
    // ssh key takes precedence over controller password
    controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
    // terraform is not creating the implicit dependency on the controller module
    // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
    // to work around, add the explicit dependency
    depends_on = [module.vfxtcontroller]

    proxy_uri = local.proxy_uri
    cluster_proxy_uri = local.cluster_proxy_uri
    image_id = local.vfxt_image_id
    
    location = local.location
    azure_resource_group = local.vfxt_resource_group_name
    azure_network_resource_group = local.virtual_network_resource_group
    azure_network_name = local.virtual_network_name
    azure_subnet_name = local.vfxt_network_subnet_name
    vfxt_cluster_name = local.vfxt_cluster_name
    vfxt_admin_password = local.vfxt_cluster_password
    vfxt_node_count = 3
    global_custom_settings = [
        "cluster.CtcBackEndTimeout KO 110000000",
        "cluster.HaBackEndTimeout II 120000000",
        "cluster.NfsBackEndTimeout VO 100000000",
        "cluster.NfsFrontEndCwnd EK 1",
        "cluster.ctcConnMult CE 25",
        "vcm.alwaysForwardReadSize DL 134217728",
        "vcm.disableReadAhead AB 1",
        "vcm.vcm_waWriteBlocksValid GN 0",
    ]

    vserver_settings = [
        "NfsFrontEndSobuf OG 1048576",
        "rwsize IZ 524288",
    ]

/*
    core_filer {
        name = "nfs1"
        fqdn_or_primary_ip = module.nasfiler1.primary_ip
        cache_policy = local.cache_policy
        custom_settings = [
            "autoWanOptimize YF 2",
            "nfsConnMult YW 5",
        ]
        junction {
            namespace_path = "/nfs1data"
            core_filer_export = module.nasfiler1.core_filer_export
        }
    }

    core_filer {
        name = "nfs2"
        fqdn_or_primary_ip = module.nasfiler2.primary_ip
        cache_policy = local.cache_policy
        custom_settings = [
            "always_forward OZ 1",
            "autoWanOptimize YF 2",
            "nfsConnMult YW 4",
        ]
        junction {
            namespace_path = "/nfs2data"
            core_filer_export = module.nasfiler2.core_filer_export
        }
    }

    core_filer {
        name = "nfs3"
        fqdn_or_primary_ip = module.nasfiler3.primary_ip
        cache_policy = local.cache_policy
        custom_settings = [
            "autoWanOptimize YF 2",
            "client_rt_preferred FE 524288",
            "client_wt_preferred NO 524288",
            "nfsConnMult YW 20",
        ]
        junction {
            namespace_path = "/nfs3data"
            core_filer_export = module.nasfiler3.core_filer_export
        }
    }
*/
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