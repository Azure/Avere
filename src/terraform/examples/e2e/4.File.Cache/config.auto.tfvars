resourceGroupName = "ArtistAnywhere.Cache" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

cacheName      = "cache" # Set to a uniquely identifiable cache cluster name
enableHPCCache = true    # Enables HPC Cache (PaaS) instead of Avere vFXT (IaaS)
enableDevMode  = false   # Enables non-production resource deployment for testing

##############################################################################
# HPC Cache (https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) #
##############################################################################

# HPC Cache throughput / size (GB) options
#   Standard_L4_5G - 21623                Read Only
#     Standard_L9G - 43246                Read Only
#    Standard_L16G - 86491                Read Only
#      Standard_2G - 3072, 6144, 12288    Read Write
#      Standard_4G - 6144, 12288, 24576   Read Write
#      Standard_8G - 12288, 24576, 49152  Read Write
hpcCache = {
  throughput = "Standard_L4_5G"
  size       = 21623
  mtuSize    = 1500
  ntpHost    = ""
  dns = {
    ipAddresses = [ # Maximum of 3 IP addresses
    ]
    searchDomain = ""
  }
  encryption = {
    keyName   = ""
    rotateKey = false
  }
}

#################################################################################
# Avere vFXT (https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) #
#################################################################################

vfxtCache = {
  cluster = {
    nodeSize      = 1024 # Set to either 1024 GB (1 TB) or 4096 GB (4 TB) nodes
    nodeCount     = 3    # Set to a minimum of 3 nodes up to a maximum of 12 nodes
    adminUsername = ""
    adminPassword = ""
    sshPublicKey  = ""
    imageId = {
      controller = ""
      node       = ""
    }
  }
  support = {                    # https://privacy.microsoft.com/privacystatement
    companyName      = ""        # https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#support_uploads_company_name
    enableLogUpload  = true      # https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#enable_support_uploads
    enableProactive  = "Support" # https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#enable_secure_proactive_support
    rollingTraceFlag = "0xe4001" # https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#rolling_trace_flag
  }
  localTimezone = "UTC"
}

#######################################################################################
# Storage Targets (https://learn.microsoft.com/azure/hpc-cache/hpc-cache-add-storage) #
#######################################################################################

storageTargetsNfs = [
  {
    enable      = false
    name        = "Content"
    storageHost = ""
    hpcCache = {
      usageModel = "WRITE_AROUND" # https://learn.microsoft.com/azure/hpc-cache/cache-usage-models
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
    enable     = false
    name       = "Content"
    clientPath = "/mnt/content"
    usageModel = "WRITE_AROUND" # https://learn.microsoft.com/azure/hpc-cache/cache-usage-models
    storage = {
      resourceGroupName = "ArtistAnywhere.Storage"
      accountName       = "azstudio1"
      containerName     = "content"
    }
  }
]

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  enable             = false
  name               = ""
  subnetName         = ""
  resourceGroupName  = ""
  privateDnsZoneName = ""
}
