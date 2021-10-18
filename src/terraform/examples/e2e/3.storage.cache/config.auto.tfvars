resourceGroupName = "AzureRender.Cache"

cacheName = "cache" // Set to a uniquely identifiable name

hpcCacheEnable = true // Set to false for Avere vFXT deployment

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
hpcCache = {
  throughput = "Standard_2G"
  size       = 3072
}

######################################################################################
# Avere vFXT - https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview #
######################################################################################

vfxtCache = {
  cluster = {
    nodeSize       = 1024 // Set to either 1024 GBs (1 TB) or 4096 GBs (4 TBs) nodes
    nodeCount      = 3    // Set to a minimum of 3 nodes up to a maximum of 20 nodes
    nodeImageId    = ""
    adminUsername  = "azadmin"
    sshPublicKey   = ""
    customSettings = []
  }
  controller = {
    adminUsername = "azadmin"
    sshPublicKey  = ""
  }
  support = {
    companyName = "" // Set to authorize automated support data upload per https://privacy.microsoft.com/en-us/privacystatement
  }
}

###################
# Storage Targets #
###################

storageTargetsNfs = [
  {
    name            = ""
    fqdnOrIpAddress = [""]
    hpcCache = {
      usageModel = "WRITE_AROUND" // https://docs.microsoft.com/en-us/azure/hpc-cache/cache-usage-models
    }
    vfxtCache = {
      cachePolicy      = "Clients Bypassing the Cluster"
      filerConnections = 4
      customSettings   = []
    }
    namespaceJunctions = [
      {
        nfsExport     = "/show"
        namespacePath = "/mnt/farm"
        targetPath    = ""
      }
    ]
  },
  {
    name            = ""
    fqdnOrIpAddress = [""]
    hpcCache = {
      usageModel = "WRITE_WORKLOAD_CLOUDWS" // https://docs.microsoft.com/en-us/azure/hpc-cache/cache-usage-models
    }
    vfxtCache = {
      cachePolicy      = "Collaborating Cloud Workstation"
      filerConnections = 4
      customSettings   = []
    }
    namespaceJunctions = [
      {
        nfsExport     = "/show"
        namespacePath = "/mnt/workstation"
        targetPath    = ""
      }
    ]
  }
]

storageTargetsNfsBlob = [
  {
    name          = "RenderFarm"
    usageModel    = "WRITE_AROUND"
    namespacePath = "/mnt/farm"
    storage = {
      resourceGroupName = "AzureRender.Storage"
      accountName       = "azasset"
      containerName     = "show"
    }
  },
  {
    name          = "ArtistWorkstation"
    usageModel    = "WRITE_WORKLOAD_CLOUDWS"
    namespacePath = "/mnt/workstation"
    storage = {
      resourceGroupName = "AzureRender.Storage"
      accountName       = "azasset"
      containerName     = "show"
    }
  }
]

################################################################################# 
# Private DNS - https://docs.microsoft.com/en-us/azure/dns/private-dns-overview #
################################################################################# 

privateDns = {
  zoneName = "media.studio"
  aRecord = {
    name = "cache"
    ttl  = 300
  }
}

######################################################################################################
# Virtual Network - https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview #
######################################################################################################

virtualNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
