resourceGroupName = "ArtistAnywhere.Cache"

cacheName      = "cache" // Set to a uniquely identifiable cache name
enableHpcCache = true    // Set to false for Avere vFXT cache deployment

#############################################################################
# HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) #
#############################################################################

// HPC Cache throughput / size (GBs) options
//   Standard_L4_5G - 21623                Read Only
//     Standard_L9G - 43246                Read Only
//    Standard_L16G - 86491                Read Only
//      Standard_2G - 3072, 6144, 12288    Read Write
//      Standard_4G - 6144, 12288, 24576   Read Write
//      Standard_8G - 12288, 24576, 49152  Read Write
hpcCache = {
  throughput = "Standard_L4_5G"
  size       = 21623
  mtuSize    = 1500
  ntpHost    = "time.windows.com"
}

################################################################################
# Avere vFXT (https://docs.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) #
################################################################################

vfxtCache = {
  cluster = {
    nodeSize       = 1024 // Set to either 1024 GBs (1 TB) or 4096 GBs (4 TBs) nodes
    nodeCount      = 3    // Set to a minimum of 3 nodes up to a maximum of 16 nodes
    nodeImageId    = ""
    adminUsername  = "azadmin"
    sshPublicKey   = ""
    customSettings = []
  }
  controller = {
    adminUsername = "azadmin"
    sshPublicKey  = ""
  }
  support = {                    // https://privacy.microsoft.com/privacystatement
    companyName      = ""        // https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#support_uploads_company_name
    enableLogUpload  = true      // https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#enable_support_uploads
    enableProactive  = "Support" // https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#enable_secure_proactive_support
    rollingTraceFlag = "0xe4001" // https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#rolling_trace_flag
  }
}

######################################################################################
# Storage Targets (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-add-storage) #
######################################################################################

storageTargetsNfs = [
  {
    name        = "" // "RenderFarm"
    storageHost = ""
    hpcCache = {
      usageModel = "WRITE_AROUND" // https://docs.microsoft.com/azure/hpc-cache/cache-usage-models
    }
    vfxtCache = {
      cachePolicy    = "Clients Bypassing the Cluster"
      nfsConnections = 4
      customSettings = [
      ]
    }
    namespaceJunctions = [
      {
        storageExport = ""
        storagePath   = ""
        clientPath    = ""
      }
    ]
  }
]

storageTargetsNfsBlob = [
  {
    name       = "" // "RenderFarm"
    clientPath = "/mnt/show"
    usageModel = "WRITE_AROUND"
    storage = {
      resourceGroupName = "ArtistAnywhere.Storage"
      accountName       = "azartist1"
      containerName     = "show"
    }
  }
]

################################################################################################
# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview) #
################################################################################################

virtualNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
  privateDns = {
    zoneName               = ""
    enableAutoRegistration = false
  }
}
