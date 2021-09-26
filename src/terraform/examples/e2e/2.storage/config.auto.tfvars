resourceGroupName = "AzureRender.Storage"

# Storage - https://docs.microsoft.com/en-us/azure/storage/common/storage-introduction
storageAccounts = [
  {
    name         = ""                 // Name must be globally unique, lowercase alphanumeric
    type         = "BlockBlobStorage" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
    performance  = "Premium"          // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
    redundancy   = "LRS"              // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
    nfsV3Enable  = true               // https://docs.microsoft.com/en-us/azure/storage/blobs/network-file-system-protocol-support
    blobContainers = [
      {
        name = "show"
      }
    ]
    fileShares = []
    messageQueues = []
    privateEndpoints = [] // ["blob"]
  }
]
