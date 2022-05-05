resourceGroupName = "ArtistAnywhere.Storage"

# Storage (https://docs.microsoft.com/en-us/azure/storage/common/storage-introduction)
storageAccounts = [
  {
    name                 = "azartist1" // Name must be globally unique (lowercase alphanumeric)
    type                 = "StorageV2" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
    tier                 = "Standard"  // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview#performance-tiers
    redundancy           = "LRS"       // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
    enableBlobNfsV3      = true        // https://docs.microsoft.com/en-us/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShare = false       // https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?#advanced
    enableSecureTransfer = true        // https://docs.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer
    privateEndpointTypes = [           // https://docs.microsoft.com/en-us/azure/storage/common/storage-private-endpoints
      "blob",
      "file"
    ]
    blobContainers = [                 // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction
      {
        name       = "show"
        accessType = "private"
        localDirectories = [
          "blender",
          "unreal"
        ]
      }
    ]
    fileShares = [                     // https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction
      {
        name     = "show"
        sizeGiB  = 5120
        protocol = "SMB"
      }
    ]
  },
  {
    name                 = "azartist2"   // Name must be globally unique (lowercase alphanumeric)
    type                 = "FileStorage" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
    tier                 = "Premium"     // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview#performance-tiers
    redundancy           = "LRS"         // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
    enableBlobNfsV3      = false         // https://docs.microsoft.com/en-us/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShare = true          // https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?#advanced
    enableSecureTransfer = false         // https://docs.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer
    privateEndpointTypes = [             // https://docs.microsoft.com/en-us/azure/storage/common/storage-private-endpoints
      "file"
    ]
    blobContainers = [                   // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction
    ]
    fileShares = [                       // https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction
      {
        name     = "show"
        sizeGiB  = 5120
        protocol = "NFS"
      }
    ]
  }
]

# Virtual Network (https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name              = ""
  resourceGroupName = ""
  subnetNameStorage = "Storage" // Subnet must be enabled with the Microsoft.Storage service endpoint
  subnetNameCache   = "Cache"   // Subnet must be enabled with the Microsoft.Storage service endpoint
}
