resourceGroupName = "ArtistAnywhere.Storage"

##################################################################################
# Storage (https://docs.microsoft.com/azure/storage/common/storage-introduction) #
##################################################################################

storageAccounts = [
  {
    name                 = "azrender1" // Name must be globally unique (lowercase alphanumeric)
    type                 = "StorageV2" // https://docs.microsoft.com/azure/storage/common/storage-account-overview
    tier                 = "Standard"  // https://docs.microsoft.com/azure/storage/common/storage-account-overview#performance-tiers
    redundancy           = "LRS"       // https://docs.microsoft.com/azure/storage/common/storage-redundancy
    enableBlobNfsV3      = true        // https://docs.microsoft.com/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShare = false       // https://docs.microsoft.com/azure/storage/files/storage-how-to-create-file-share?#advanced
    enableSecureTransfer = true        // https://docs.microsoft.com/azure/storage/common/storage-require-secure-transfer
    privateEndpointTypes = [           // https://docs.microsoft.com/azure/storage/common/storage-private-endpoints
      "blob",
      "file"
    ]
    blobContainers = [                 // https://docs.microsoft.com/azure/storage/blobs/storage-blobs-introduction
      {
        name       = "show"
        accessType = "private"
        localDirectories = [
          "blender"
        ]
      }
    ]
    fileShares = [                     // https://docs.microsoft.com/azure/storage/files/storage-files-introduction
      {
        name     = "show"
        tier     = "TransactionOptimized"
        sizeGiB  = 5120
        protocol = "SMB"
      }
    ]
  },
  {
    name                 = ""            // Name must be globally unique (lowercase alphanumeric)
    type                 = "FileStorage" // https://docs.microsoft.com/azure/storage/common/storage-account-overview
    tier                 = "Premium"     // https://docs.microsoft.com/azure/storage/common/storage-account-overview#performance-tiers
    redundancy           = "LRS"         // https://docs.microsoft.com/azure/storage/common/storage-redundancy
    enableBlobNfsV3      = false         // https://docs.microsoft.com/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShare = true          // https://docs.microsoft.com/azure/storage/files/storage-how-to-create-file-share?#advanced
    enableSecureTransfer = false         // https://docs.microsoft.com/azure/storage/common/storage-require-secure-transfer
    privateEndpointTypes = [             // https://docs.microsoft.com/azure/storage/common/storage-private-endpoints
      "file"
    ]
    blobContainers = [                   // https://docs.microsoft.com/azure/storage/blobs/storage-blobs-introduction
    ]
    fileShares = [                       // https://docs.microsoft.com/azure/storage/files/storage-files-introduction
      {
        name     = "show"
        tier     = "Premium"
        sizeGiB  = 5120
        protocol = "NFS"
      }
    ]
  }
]

######################################################################################################
# NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) #
######################################################################################################

netAppAccount = {
  name = ""
  capacityPools = [
    {
      name         = "CapacityPool"
      sizeTiB      = 4
      serviceLevel = "Standard"
      volumes = [
        {
          name         = "Show"
          sizeGiB      = 4096
          serviceLevel = "Standard"
          mountPath    = "show"
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

#############################################################################################################
# Hammerspace (https://azuremarketplace.microsoft.com/en-US/marketplace/apps/hammerspace.hammerspace_4_6_5) #
#############################################################################################################

hammerspace = {
  namePrefix = ""
  domainName = ""
  anvilNode = {
    namePrefix = "Anvil"
    size       = "Standard_E4as_v4"
    count      = 2
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
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
  }
  dsxNode = {
    namePrefix = "DSX"
    size       = "Standard_F2s_v2"
    count      = 2
    osDisk = {
      sizeGB      = 128
      storageType = "Premium_LRS"
      cachingType = "ReadWrite"
    }
    dataDisk = {
      count       = 2
      sizeGB      = 256
      enableRaid0 = false
      storageType = "Premium_LRS"
      cachingType = "None"
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
  }
}

####################################################################################
# Optional override configuration when not using Terraform remote state management #
####################################################################################

storageNetwork = {
  name               = ""
  resourceGroupName  = ""
}

storageEndpointSubnets = [
  {
    name               = ""
    regionName         = ""
    virtualNetworkName = ""
  }
]
