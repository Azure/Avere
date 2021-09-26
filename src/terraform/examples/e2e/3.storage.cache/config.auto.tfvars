resourceGroupName = "AzureRender.Cache"

cacheName = "Cache" // Set to a uniquely identifiable name

hpcCacheEnable = false // Set to true for HPC Cache managed service deployment

###################################################################################
# HPC Cache - https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview #
###################################################################################

// HPC Cache throughput / size (GBs) options
//      Standard_2G - 3072, 6144, 12288    Read Write
//      Standard_4G - 6144, 12288, 24576   Read Write
//      Standard_8G - 12288, 24576, 49152  Read Write
//   Standard_L4_5G - 21623                Read Only
//     Standard_L9G - 43246                Read Only
//    Standard_L16G - 86491                Read Only
hpcCacheThroughput = "Standard_2G"
hpcCacheSize       = 3072

######################################################################################
# Avere vFXT - https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview #
######################################################################################

vfxtNodeSize  = 4096 // Set to either 1024 GBs (1 TB) or 4096 GBs (4 TBs) nodes
vfxtNodeCount = 3    // Set to a minimum of 3 nodes up to a maximum of 20 nodes

vfxtSupportUploadEnable      = false // Set to true to authorize cluster support bundle upload per the
vfxtSupportUploadCompanyName = ""    // https://privacy.microsoft.com/en-us/privacystatement policy
vfxtProactiveSupportType     = "Support"

vfxtNodeAdminUsername = "azureadmin"
vfxtNodeSshPublicKey  = ""

vfxtControllerAdminUsername = "azureadmin"
vfxtControllerSshPublicKey = ""

vfxtGlobalCustomSettings = []

###################
# Storage Targets #
###################

storageTargetsNfs = [
  {
    name              = ""
    targetFqdnOrIp    = ""
    targetConnections = 4
    usageModel        = "WRITE_AROUND"                  // https://docs.microsoft.com/en-us/azure/hpc-cache/cache-usage-models
    cachePolicy       = "Clients Bypassing the Cluster" // https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#cache_policy
    customSettings    = []
    namespaceJunctions = [
      {
        namespacePath = "/mnt/farm"
        nfsExport     = "/"
        targetPath    = ""
      }
    ],
  },
  {
    name              = ""
    targetFqdnOrIp    = ""
    targetConnections = 4
    usageModel        = "WRITE_WORKLOAD_CLOUDWS"          // https://docs.microsoft.com/en-us/azure/hpc-cache/cache-usage-models
    cachePolicy       = "Collaborating Cloud Workstation" // https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#cache_policy
    customSettings    = []
    namespaceJunctions = [
      {
        namespacePath = "/mnt/workstation"
        nfsExport     = "/"
        targetPath    = ""
      }
    ]
  }
]

storageTargetsNfsBlob = [
  {
    name                 = ""
    usageModel           = "WRITE_WORKLOAD_CLOUDWS"
    namespacePath        = "/mnt/show"
    storageAccountName   = "mediastudio"
    storageContainerName = "show"
  }
]
