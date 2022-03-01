resourceGroupName = "AzureRender.Storage"

# Storage (https://docs.microsoft.com/en-us/azure/storage/common/storage-introduction)
storageAccounts = [
  {
    name                  = ""          // Name must be globally unique (lowercase alphanumeric)
    type                  = "StorageV2" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
    redundancy            = "LRS"       // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
    performance           = "Standard"  // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
    enableBlobNfsV3       = true        // https://docs.microsoft.com/en-us/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShares = false       // https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?#advanced
    privateEndpoints = [                // https://docs.microsoft.com/en-us/azure/storage/common/storage-private-endpoints
      "blob",
      "file"
    ]
    blobContainers = [                  // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction
      {
        name   = "show"
        access = "private"
      }
    ]
    fileShares = [                      // https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction
      {
        name     = "show"
        sizeGiB  = 5120
        protocol = "SMB"
      }
    ]
  },
  {
    name                  = ""            // Name must be globally unique (lowercase alphanumeric)
    type                  = "FileStorage" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
    redundancy            = "LRS"         // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
    performance           = "Premium"     // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
    enableBlobNfsV3       = false         // https://docs.microsoft.com/en-us/azure/storage/blobs/network-file-system-protocol-support
    enableLargeFileShares = true          // https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?#advanced
    privateEndpoints = [                  // https://docs.microsoft.com/en-us/azure/storage/common/storage-private-endpoints
      "file"
    ]
    blobContainers = [                    // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction
    ]
    fileShares = [                        // https://docs.microsoft.com/en-us/azure/storage/files/storage-files-introduction
      {
        name     = "show"
        sizeGiB  = 5120
        protocol = "NFS"
      }
    ]
  }
]

# Hammerspace (https://azuremarketplace.microsoft.com/en-us/marketplace/apps/hammerspace.hammerspace)
# TBD

# NetApp Files (https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-introduction)
netAppAccounts = [
  {
    name = ""
    capacityPools = [
      {
        name         = "Standard"
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
]

# Virtual Network (https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name              = ""
  resourceGroupName = ""
  serviceEndpointSubnets = [ // Subnet names that are enabled with the Microsoft.Storage service endpoint
    # "Storage",
    # "Cache"
  ]
}
