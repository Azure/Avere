resourceGroupName = "AzureRender.Storage"

# Storage - https://docs.microsoft.com/en-us/azure/storage/common/storage-introduction
storageAccounts = [
  {
    name             = "azasset"   // Name must be globally unique (lowercase alphanumeric)
    type             = "StorageV2" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
    redundancy       = "LRS"       // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
    performance      = "Standard"  // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
    nfsV3Enable      = true        // https://docs.microsoft.com/en-us/azure/storage/blobs/network-file-system-protocol-support
    fileShares       = []
    messageQueues    = []
    blobContainers   = ["show"]
    blobs            = ["show/*"]
    privateEndpoints = ["blob"]
  },
  {
    name             = ""            // Name must be globally unique (lowercase alphanumeric)
    type             = "FileStorage" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
    redundancy       = "LRS"         // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
    performance      = "Premium"     // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
    nfsV3Enable      = false         // https://docs.microsoft.com/en-us/azure/storage/blobs/network-file-system-protocol-support
    fileShares       = ["show"]
    messageQueues    = []
    blobContainers   = []
    blobs            = []
    privateEndpoints = ["file"]
  }
]

# NetApp Files - https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-introduction
netAppAccounts = [
  {
    name = ""
    capacityPools = [
      {
        name         = "Standard"
        serviceLevel = "Standard"
        sizeTB       = 4
        volumes = [
          {
            name         = "Show"
            mountPath    = "show"
            serviceLevel = "Standard"
            sizeGB       = 4096
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

# Virtual Network - https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview
virtualNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
