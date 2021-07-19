# resource group to hold the cache
cache_rg = "cache_rg"

# VM access (jumpbox, vyos VM) 
vm_admin_username = "azureuser"
# vm ssh key, leave empty string if not used
ssh_public_key = ""

// controller settings, used for vfxt and cachewarmer
controller_private_ip            = "10.0.1.254" // at end of range to not interfere with cache
controller_add_public_ip         = true
install_cachewarmer              = true
cachewarmer_storage_account_name = "cachewarmerstg"
queue_prefix_name                = "cachewarmer"

// There are 2 Cache choices
// "HPCCache" - deploys HPC Cache
// "AverevFXT" - deploy AverevFXT
cache_type = "HPCCache"

////////////////////////////////////////////////////////////////
// Set real_* vars if use_onprem_simulation set to true
////////////////////////////////////////////////////////////////
use_onprem_simulation = true

# this is the fqdn that will be "spoofed" to point at the cache
real_nfsfiler_fqdn = ""

// the "real" settings ignorted if using the onprem simulator
real_nfs_targets = [
  /*
    nfs_targets = !var.use_onprem_simulation ? var.real_nfs_target_host1 : [
        {
        name      = "",
        addresses = [""],
        junctions = [
            {
            namespace_path = "",
            nfs_export     = "",
            target_path    = "",
            }
        ]
        }
    ]
    */
]

////////////////////////////////////////////////////////////////
// HPC Cache Details - only edit if cache_type is "HPCCache"
////////////////////////////////////////////////////////////////
// HPC Cache Throughput SKU - 3 allowed values for throughput (GB/s) of the cache
//  Standard_2G
//  Standard_4G
//  Standard_8G
hpc_cache_throughput = "Standard_2G"

// HPC Cache Size - 5 allowed sizes (GBs) for the cache
//   3072
//   6144
//  12288
//  24576
//  49152
hpc_cache_size = 12288

// unique name for cache
hpc_cache_name = "hpccache"

// HPC Cache usage models:
//   READ_HEAVY_INFREQ
//   READ_HEAVY_CHECK_180
//   WRITE_WORKLOAD_15
//   WRITE_AROUND
//   WRITE_WORKLOAD_CHECK_30
//   WRITE_WORKLOAD_CHECK_60
//   WRITE_WORKLOAD_CLOUDWS
hpc_usage_model = "WRITE_AROUND"

////////////////////////////////////////////////////////////////
// vfxt details - only edit if cache_type is "AverevFXT"
////////////////////////////////////////////////////////////////
// if you are running a locked down network, set controller_add_public_ip to false, but ensure
// you have access to the subnet
vfxt_cluster_name = "vfxt"
// vfxt sku
//  1. "unsupported_test_SKU" - small SKU to save money
//  2. "prod_sku" - production and support sku
vfxt_sku = "unsupported_test_SKU"
// vfxt ssh key, leave empty string if not used
vfxt_ssh_key_data = ""
// vfxt cache polies
//  "Clients Bypassing the Cluster"
//  "Read Caching"
//  "Read and Write Caching"
//  "Full Caching"
//  "Transitioning Clients Before or After a Migration"
vfxt_cache_policy = "Clients Bypassing the Cluster"

////////////////////////////////////////////////////////////////
// Advanced scenarios
////////////////////////////////////////////////////////////////
// advanced scenario: vfxt and controller image ids, leave this null, unless not using default marketplace
controller_image_id = null
vfxt_image_id       = null
// add the resource groups of the controller or vfxt image id so the controller has access
alternative_resource_groups = []
