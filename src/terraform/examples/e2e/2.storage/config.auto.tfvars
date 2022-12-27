resourceGroupName = "ArtistAnywhere.Storage" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

###################################################################################
# Storage (https://learn.microsoft.com/azure/storage/common/storage-introduction) #
###################################################################################

storageAccounts = [
  {
    name                 = "azrender1"        # Name must be globally unique (lowercase alphanumeric)
    type                 = "BlockBlobStorage" # https://learn.microsoft.com/azure/storage/common/storage-account-overview
    tier                 = "Premium"          # https://learn.microsoft.com/azure/storage/common/storage-account-overview#performance-tiers
    redundancy           = "LRS"              # https://learn.microsoft.com/azure/storage/common/storage-redundancy
    enableHttpsOnly      = true               # https://learn.microsoft.com/azure/storage/common/storage-require-secure-transfer
    enableBlobNfsV3      = true               # https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShare = false              # https://learn.microsoft.com/azure/storage/files/storage-how-to-create-file-share#advanced
    blobContainers = [                        # https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction
      {
        name = "data"
        dataSource = {
          accountName   = ""
          accountKey    = ""
          containerName = ""
        }
      }
    ]
    fileShares = [                            # https://learn.microsoft.com/azure/storage/files/storage-files-introduction
    ]
  },
  {
    name                 = "azrender2"   # Name must be globally unique (lowercase alphanumeric)
    type                 = "FileStorage" # https://learn.microsoft.com/azure/storage/common/storage-account-overview
    tier                 = "Premium"     # https://learn.microsoft.com/azure/storage/common/storage-account-overview#performance-tiers
    redundancy           = "LRS"         # https://learn.microsoft.com/azure/storage/common/storage-redundancy
    enableHttpsOnly      = true          # https://learn.microsoft.com/azure/storage/common/storage-require-secure-transfer
    enableBlobNfsV3      = false         # https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShare = true          # https://learn.microsoft.com/azure/storage/files/storage-how-to-create-file-share#advanced
    blobContainers = [                   # https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction
    ]
    fileShares = [                       # https://learn.microsoft.com/azure/storage/files/storage-files-introduction
      {
        name     = "data"
        tier     = "Premium"
        sizeGiB  = 5120
        protocol = "SMB"
        dataSource = {
          accountName   = ""
          accountKey    = ""
          containerName = ""
        }
      }
    ]
  }
]

#######################################################################################################
# NetApp Files (https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) #
#######################################################################################################

netAppAccount = {
  name = ""
  capacityPools = [
    {
      name         = "CapacityPool"
      sizeTiB      = 4
      serviceLevel = "Standard"
      volumes = [
        {
          name         = "Data"
          sizeGiB      = 4096
          serviceLevel = "Standard"
          mountPath    = "data"
          protocols = [
            "NFSv3"
          ]
          exportPolicies = [
            {
              ruleIndex  = 1
              readOnly   = false
              readWrite  = true
              rootAccess = true
              protocols = [
                "NFSv3"
              ]
              allowedClients = [
                "0.0.0.0/0"
              ]
            }
          ]
        }
      ]
    }
  ]
}

#######################################################################################################
# Hammerspace (https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5) #
#######################################################################################################

hammerspace = {
  namePrefix = ""
  domainName = ""
  metadata = {
    machine = {
      namePrefix = "Anvil"
      size       = "Standard_E32s_v5"
      count      = 1 # Set to 2 (or more) to enable high availability
    }
    network = {
      enableAcceleratedNetworking = true
    }
    osDisk = {
      sizeGB      = 128
      storageType = "Premium_LRS"
      cachingType = "ReadWrite"
    }
    dataDisk = {
      sizeGB      = 256
      storageType = "Premium_LRS"
      cachingType = "None"
    }
    adminLogin = {
      userName            = ""
      userPassword        = ""
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
  }
  data = {
    machine = {
      namePrefix = "DSX"
      size       = "Standard_HB120rs_v2"
      count      = 2
    }
    network = {
      enableAcceleratedNetworking = true
    }
    osDisk = {
      sizeGB      = 128
      storageType = "Premium_LRS"
      cachingType = "ReadWrite"
    }
    dataDisk = {
      count       = 2
      sizeGB      = 256
      storageType = "Premium_LRS"
      cachingType = "None"
      enableRaid0 = false
    }
    adminLogin = {
      userName            = ""
      userPassword        = ""
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
  }
  enableProximityPlacement   = false
  enableMarketplaceAgreement = true
}

##########################################################################################################
# Qumulo (https://azuremarketplace.microsoft.com/en-us/marketplace/apps/qumulo1584033880660.qumulo-saas) #
##########################################################################################################

qumulo = {
  name      = ""
  planId    = "qumulo-on-azure-v1"
  offerId   = "qumulo-saas"
  termId    = "Monthly" # "Yearly"
  autoRenew = true
}

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

storageNetwork = {
  name                = ""
  resourceGroupName   = ""
  subnetNamePrimary   = ""
  subnetNameSecondary = ""
  serviceEndpointSubnets = [ # https://learn.microsoft.com/azure/storage/common/storage-network-security#grant-access-from-a-virtual-network
    {
      name               = ""
      regionName         = ""
      virtualNetworkName = ""
    }
  ]
}

managedIdentity = {
  name              = ""
  resourceGroupName = ""
}

keyVault = {
  name                 = ""
  resourceGroupName    = ""
  keyNameAdminUsername = ""
  keyNameAdminPassword = ""
}

monitorWorkspace = {
  name              = ""
  resourceGroupName = ""
}
