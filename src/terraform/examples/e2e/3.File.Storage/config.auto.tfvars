resourceGroupName = "ArtistAnywhere.Storage" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

fileLoadSource = {
  accountName   = ""
  accountKey    = ""
  containerName = ""
  blobName      = ""
}

###################################################################################
# Storage (https://learn.microsoft.com/azure/storage/common/storage-introduction) #
###################################################################################

storageAccounts = [
  {
    enable               = true
    name                 = "azstudio1" # Name must be globally unique (lowercase alphanumeric)
    type                 = "StorageV2" # https://learn.microsoft.com/azure/storage/common/storage-account-overview
    tier                 = "Standard"  # https://learn.microsoft.com/azure/storage/common/storage-account-overview#performance-tiers
    redundancy           = "LRS"       # https://learn.microsoft.com/azure/storage/common/storage-redundancy
    enableHttpsOnly      = true        # https://learn.microsoft.com/azure/storage/common/storage-require-secure-transfer
    enableBlobNfsV3      = true        # https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShare = true        # https://learn.microsoft.com/azure/storage/files/storage-how-to-create-file-share#advanced
    privateEndpointTypes = [ # https://learn.microsoft.com/azure/storage/common/storage-private-endpoints
      "blob",
      "file"
    ]
    blobContainers = [ # https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction
      {
        enable         = true
        name           = "content"
        rootAcl        = "user::rwx,group::rwx,other::rwx"
        rootAclDefault = "default:user::rwx,group::rwx,other::rwx"
        enableFileLoad = false
      },
      {
        enable         = true
        name           = "weka"
        rootAcl        = "user::rwx,group::rwx,other::rwx"
        rootAclDefault = "default:user::rwx,group::rwx,other::rwx"
        enableFileLoad = false
      }
    ]
    fileShares = [ # https://learn.microsoft.com/azure/storage/files/storage-files-introduction
      {
        enable         = true
        name           = "content"
        sizeGiB        = 5120
        accessTier     = "TransactionOptimized"
        accessProtocol = "SMB"
        enableFileLoad = false
      }
    ]
  },
  {
    enable               = true
    name                 = "azstudio2"   # Name must be globally unique (lowercase alphanumeric)
    type                 = "FileStorage" # https://learn.microsoft.com/azure/storage/common/storage-account-overview
    tier                 = "Premium"     # https://learn.microsoft.com/azure/storage/common/storage-account-overview#performance-tiers
    redundancy           = "LRS"         # https://learn.microsoft.com/azure/storage/common/storage-redundancy
    enableHttpsOnly      = false         # https://learn.microsoft.com/azure/storage/common/storage-require-secure-transfer
    enableBlobNfsV3      = false         # https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShare = true          # https://learn.microsoft.com/azure/storage/files/storage-how-to-create-file-share#advanced
    privateEndpointTypes = [ # https://learn.microsoft.com/azure/storage/common/storage-private-endpoints
      "file"
    ]
    blobContainers = [ # https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction
    ]
    fileShares = [ # https://learn.microsoft.com/azure/storage/files/storage-files-introduction
      {
        enable         = true
        name           = "content"
        sizeGiB        = 5120
        accessTier     = "Premium"
        accessProtocol = "NFS"
        enableFileLoad = false
      }
    ]
  }
]

#######################################################################################################
# Weka (https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform) #
#######################################################################################################

weka = {
  enable   = false
  apiToken = ""
  name = {
    resource = "azstudio"
    display  = "Azure Artist Anywhere"
  }
  machine = {
    size  = "Standard_L8as_v3"
    count = 6
    image = {
      id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/0.0.0"
      plan = {
        enable    = false
        publisher = ""
        product   = ""
        name      = ""
      }
    }
  }
  network = {
    privateDnsZone = {
      recordSetName    = "content"
      recordTtlSeconds = 300
    }
    enableAcceleration = false
  }
  terminateNotification = {
    enable       = true
    delayTimeout = "PT15M"
  }
  objectTier = {
    enable  = true
    percent = 80
    storage = {
      accountName    = ""
      accountKey     = ""
      containerName  = "weka"
      enableFileLoad = false
    }
  }
  fileSystem = {
    name         = "default"
    groupName    = "default"
    autoScale    = false
    authRequired = false
  }
  osDisk = {
    storageType = "Premium_LRS"
    cachingType = "None"
    sizeGB      = 0
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
  healthExtension = {
    enable      = true
    protocol    = "http"
    port        = 14000
    requestPath = "/ui"
  }
  adminLogin = {
    userName     = ""
    userPassword = ""
    sshPublicKey = "" # "ssh-rsa ..."
    passwordAuth = {
      disable = false
    }
  }
  license = {
    key = ""
    payGo = {
      planId    = ""
      secretKey = ""
    }
  }
  supportUrl = ""
}

#######################################################################################################
# NetApp Files (https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) #
#######################################################################################################

netAppAccount = {
  enable = false
  name   = ""
  capacityPools = [
    {
      enable       = false
      name         = "CapacityPool"
      sizeTiB      = 4
      serviceLevel = "Standard"
      volumes = [
        {
          enable       = false
          name         = "Content"
          sizeGiB      = 4096
          serviceLevel = "Standard"
          mountPath    = "content"
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
      size       = "Standard_E4as_v4"
      count      = 1 # Set to 2 (or more) to enable high availability
    }
    network = {
      enableAcceleration = true
    }
    osDisk = {
      storageType = "Premium_LRS"
      cachingType = "ReadWrite"
      sizeGB      = 128
    }
    dataDisk = {
      storageType = "Premium_LRS"
      cachingType = "None"
      sizeGB      = 256
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
      sshPublicKey = "" # "ssh-rsa ..."
      passwordAuth = {
        disable = false
      }
    }
  }
  data = {
    machine = {
      namePrefix = "DSX"
      size       = "Standard_F2s_v2"
      count      = 2
    }
    network = {
      enableAcceleration = true
    }
    osDisk = {
      storageType = "Premium_LRS"
      cachingType = "ReadWrite"
      sizeGB      = 128
    }
    dataDisk = {
      storageType = "Premium_LRS"
      cachingType = "None"
      enableRaid0 = false
      sizeGB      = 256
      count       = 2
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
      sshPublicKey = "" # "ssh-rsa ..."
      passwordAuth = {
        disable = false
      }
    }
  }
}

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

storageNetwork = {
  enable              = false
  name                = ""
  resourceGroupName   = ""
  subnetNamePrimary   = ""
  subnetNameSecondary = ""
  privateDnsZoneName  = ""
  serviceEndpointSubnets = [ # https://learn.microsoft.com/azure/storage/common/storage-network-security#grant-access-from-a-virtual-network
    {
      name               = ""
      regionName         = ""
      virtualNetworkName = ""
    }
  ]
}
