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
        fqdn_or_primary_ip = "10.4.1.4"
        cache_policy = "Clients Bypassing the Cluster"
        custom_settings = [
            "autoWanOptimize YF 2",
            "nfsConnMult YW 5",
        ]
        junction {
            namespace_path = "/nfs1data3"
            core_filer_export = "/data"
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
        fqdn_or_primary_ip = "10.4.1.5"
        cache_policy = "Clients Bypassing the Cluster"
        custom_settings = [
            "always_forward OZ 1",
            "autoWanOptimize YF 2",
            "nfsConnMult YW 4",
        ]
        junction {
            namespace_path = "/nfs2data"
            core_filer_export = "/data"
        }
    }

    core_filer {
        name = "nfs3"
        fqdn_or_primary_ip = "10.4.1.6"
        cache_policy = "Clients Bypassing the Cluster"
        custom_settings = [
            "autoWanOptimize YF 2",
            "client_rt_preferred FE 524288",
            "client_wt_preferred NO 524288",
            "nfsConnMult YW 20",
        ]
        junction {
            namespace_path = "/nfs3data"
            core_filer_export = "/data"
        }
    }
}