resourceGroupName = "ArtistAnywhere.Storage" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

###################################################################################
# Storage (https://learn.microsoft.com/azure/storage/common/storage-introduction) #
###################################################################################

storageAccounts = [
  {
    name                 = "azstudio1"        # Name must be globally unique (lowercase alphanumeric)
    type                 = "BlockBlobStorage" # https://learn.microsoft.com/azure/storage/common/storage-account-overview
    tier                 = "Premium"          # https://learn.microsoft.com/azure/storage/common/storage-account-overview#performance-tiers
    redundancy           = "LRS"              # https://learn.microsoft.com/azure/storage/common/storage-redundancy
    enableHttpsOnly      = true               # https://learn.microsoft.com/azure/storage/common/storage-require-secure-transfer
    enableBlobNfsV3      = true               # https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShare = false              # https://learn.microsoft.com/azure/storage/files/storage-how-to-create-file-share#advanced
    blobContainers = [                        # https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction
      {
        name           = "data"
        rootAcl        = "user::rwx,group::rwx,other::rwx"
        rootAclDefault = "default:user::rwx,group::rwx,other::rwx"
      },
      {
        name           = "weka"
        rootAcl        = "user::rwx,group::rwx,other::rwx"
        rootAclDefault = "default:user::rwx,group::rwx,other::rwx"
      }
    ]
    fileShares = [                            # https://learn.microsoft.com/azure/storage/files/storage-files-introduction
    ]
    dataSource = {
      accountName   = ""
      accountKey    = ""
      containerName = ""
    }
  },
  {
    name                 = "azstudio2"   # Name must be globally unique (lowercase alphanumeric)
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
      }
    ]
    dataSource = {
      accountName   = ""
      accountKey    = ""
      containerName = ""
    }
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
# Weka (https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform) #
#######################################################################################################

weka = {
  name = {
    resource = ""
    display  = "Azure Artist Anywhere"
  }
  machine = {
    size  = "Standard_L8as_v3"
    count = 6
    image = {
      id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/0.0.0"
      plan = {
        publisher = ""
        product   = ""
        name      = ""
      }
    }
  }
  network = {
    subnet = {
      range = "10.1.192.64-127"
      mask  = 26
    }
    enableAcceleration = false
  }
  objectTier = {
    percent = 80
    storage = {
      accountName   = ""
      accountKey    = ""
      containerName = "weka"
    }
  }
  fileSystem = {
    name         = "default"
    groupName    = "default"
    authRequired = false
  }
  osDisk = {
    storageType = "Premium_LRS"
    cachingType = "ReadWrite"
  }
  dataDisk = {
    storageType = "Premium_LRS"
    cachingType = "ReadWrite"
    sizeGB      = 256
  }
  dataProtection = {
    stripeWidth = 3
    parityLevel = 2
    hotSpare    = 1
  }
  adminLogin = {
    userName     = "azadmin"
    userPassword = "P@ssword1234"
    sshPublicKey = "" # "ssh-rsa ..."
    passwordAuth = {
      disable = false
    }
  }
  enableSupportCloud = true
}

#######################################################################################################
# Hammerspace (https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5) #
#######################################################################################################

hammerspace = {
  name = {
    resource = ""
    display  = "Azure Artist Anywhere"
  }
}

####################################################################################################
# Qumulo (https://azuremarketplace.microsoft.com/marketplace/apps/qumulo1584033880660.qumulo-saas) #
####################################################################################################

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
