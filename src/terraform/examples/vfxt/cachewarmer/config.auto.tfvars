// cloud vnet settings
cloud_location = "eastus"
cloud_rg       = "cloud_rg"

// onprem settings
onprem_location = "eastus"
onprem_rg       = "nprem_rg"

// storage account for the cache warmer
// set a globally unique name
storage_account_name = "stgaccount"
queue_prefix_name    = "cachewarmer"

// the following ephemeral disk size and skus fit the Moana scene
// 0.51GB Standard_E32s_v3 - use if region does not support Lsv2 or Ls
// 1.92TB Standard_L8s_v2
// 3.84TB Standard_L16s_v2
// 7.68TB Standard_L32s_v2
// 0.56TB Standard_L4s
// 1.15TB Standard_L8s
// 1.15TB Standard_L16s
filer_size = "Standard_L8s_v2"
# To get the Moana scene:
# 1. download the tgz files from https://www.disneyanimation.com/resources/moana-island-scene/
# 2. copy to blob storage account
# 3. create a SAS url to each blob (Azure Storage Explorer is the easiest way to create the SAS urls) 
island_animation_sas_url   = ""
island_basepackage_sas_url = ""
island_pbrt_sas_url        = ""

# virtual machine settings
vm_admin_username = "azureuser"
// use either SSH Key data or admin password, if ssh_key_data is specified
// then admin_password is ignored
vm_admin_password = "ReplacePassword$"
// if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
// populated where you are running terraform
vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
ssh_port        = 22
// Important: if you specify false, you must apply this terraform from a VM 
// that has access to the cloud VNETs
controller_add_public_ip = true
// for this example, we use Standard_F4s_v2 instead of the default Standard_A1_v2
// for fast downloading of the Moana scene 
controller_size = "Standard_F4s_v2"

// vfxt details
vfxt_cluster_name     = "vfxt"
vfxt_cluster_password = "VFXT_PASSWORD"
// specify true to use the cheaper D16sv3's for the vfxt cache, otherwise E32sv3 will be used
vfxt_use_test_sku = true
// vfxt cache polies
//  "Clients Bypassing the Cluster"
//  "Read Caching"
//  "Read and Write Caching"
//  "Full Caching"
//  "Transitioning Clients Before or After a Migration"
cache_policy = "Clients Bypassing the Cluster"
