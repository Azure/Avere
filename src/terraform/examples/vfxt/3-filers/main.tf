// customize the simple VM by adjusting the following local variables
locals {
    // region
    location = "eastus"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "PASSWORD"
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    // network details
    network_resource_group_name = "network_resource_group"
    
    // filer details
    filer_resource_group_name = "filer_resource_group"
    
    // vfxt details
    vfxt_resource_group_name = "vfxt_resource_group"
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

// the ephemeral filer
module "nasfiler1" {
    source = "../../../modules/ephemeral_filer"
    resource_group_name = local.filer_resource_group_name
    location = local.location
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    vm_size = "Standard_D2s_v3"

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.cloud_filers_subnet_name
}

module "nasfiler2" {
    source = "../../../modules/ephemeral_filer"
    resource_group_name = local.filer_resource_group_name
    location = local.location
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    vm_size = "Standard_D2s_v3"

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.cloud_filers_subnet_name
}

module "nasfiler3" {
    source = "../../../modules/ephemeral_filer"
    resource_group_name = local.filer_resource_group_name
    location = local.location
    admin_password = local.vm_admin_password
    ssh_key_data = local.vm_ssh_key_data
    vm_size = "Standard_D2s_v3"

    // network details
    virtual_network_resource_group = local.network_resource_group_name
    virtual_network_name = module.network.vnet_name
    virtual_network_subnet_name = module.network.cloud_filers_subnet_name
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

resource "avere_vfxt" "vfxt" {
    controller_address = module.vfxtcontroller.controller_address
    controller_admin_username = module.vfxtcontroller.controller_username
    controller_admin_password = local.vm_admin_password
    resource_group = local.vfxt_resource_group_name
    location = local.location
    network_resource_group = local.network_resource_group_name
    network_name = module.network.vnet_name
    subnet_name = module.network.cloud_cache_subnet_name
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

    core_filer {
        name = "nfs1"
        fqdn_or_primary_ip = module.nasfiler1.primary_ip
        cache_policy = "Clients Bypassing the Cluster"
        custom_settings = [
            "autoWanOptimize YF 2",
            "nfsConnMult YW 5",
        ]
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

    core_filer {
        name = "nfs2"
        fqdn_or_primary_ip = module.nasfiler2.primary_ip
        cache_policy = "Clients Bypassing the Cluster"
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
        cache_policy = "Clients Bypassing the Cluster"
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
}