resourceGroupName = "AzureRender.Image"

# Shared Image Gallery - https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries
imageGalleryName = "Gallery"
imageDefinitions = [
  {
    name       = "LinuxFarm"
    type       = "Linux"
    generation = "V1"
    publisher  = "OpenLogic"
    offer      = "CentOS"
    sku        = "7_8"
  },
  {
    name       = "LinuxWorkstation"
    type       = "Linux"
    generation = "V1"
    publisher  = "OpenLogic"
    offer      = "CentOS"
    sku        = "7_9"
  },
  {
    name       = "WindowsFarm"
    type       = "Windows"
    generation = "V1"
    publisher  = "MicrosoftWindowsServer"
    offer      = "WindowsServer"
    sku        = "2019-Datacenter"
  },
  {
    name       = "WindowsWorkstation"
    type       = "Windows"
    generation = "V1"
    publisher  = "MicrosoftWindowsDesktop"
    offer      = "Windows-10"
    sku        = "21H1-Pro"
  }
]

# Image Builder - https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview
imageTemplates = [
  {
    name = "LinuxScheduler"
    image = {
      definitionName = "LinuxFarm"
      sourceType     = "PlatformImage"
      customizeFile  = "customize.sh"
      metadataFile   = "metadata.sh"
      inputVersion   = "Latest"
      outputVersion  = "10.0.0"
    }
    build = {
      subnetName     = "Scheduler"
      machineSize    = "Standard_D8s_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120               // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "dbuser"
      runElevated    = false
    }
  },
  {
    name = "LinuxFarm"
    image = {
      definitionName = "LinuxFarm"
      sourceType     = "PlatformImage"
      customizeFile  = "customize.sh"
      metadataFile   = "metadata.sh"
      inputVersion   = "Latest"
      outputVersion  = "1.0.0"
    }
    build = {
      subnetName     = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = ""
      runElevated    = false
    }
  },
  {
    name = "LinuxWorkstationV3"
    image = {
      definitionName = "LinuxWorkstation"
      sourceType     = "PlatformImage"
      customizeFile  = "customize.sh"
      metadataFile   = "metadata.sh"
      inputVersion   = "Latest"
      outputVersion  = "3.0.0"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = ""
      runElevated    = false
    }
  },
  {
    name = "LinuxWorkstationV4"
    image = {
      definitionName = "LinuxWorkstation"
      sourceType     = "PlatformImage"
      customizeFile  = "customize.sh"
      metadataFile   = "metadata.sh"
      inputVersion   = "Latest"
      outputVersion  = "4.0.0"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                    // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                  // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = ""
      runElevated    = false
    }
  },
  {
    name = "WindowsScheduler"
    image = {
      definitionName = "WindowsFarm"
      sourceType     = "PlatformImage"
      customizeFile  = "customize.ps1"
      metadataFile   = "metadata.ps1"
      inputVersion   = "Latest"
      outputVersion  = "10.0.0"
    }
    build = {
      subnetName     = "Scheduler"
      machineSize    = "Standard_D8s_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120               // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "dbuser"
      runElevated    = true
    }
  },
  {
    name = "WindowsFarm"
    image = {
      definitionName = "WindowsFarm"
      sourceType     = "PlatformImage"
      customizeFile  = "customize.ps1"
      metadataFile   = "metadata.ps1"
      inputVersion   = "Latest"
      outputVersion  = "1.0.0"
    }
    build = {
      subnetName     = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = ""
      runElevated    = false
    }
  },
  {
    name = "WindowsWorkstationV3"
    image = {
      definitionName = "WindowsWorkstation"
      sourceType     = "PlatformImage"
      customizeFile  = "customize.ps1"
      metadataFile   = "metadata.ps1"
      inputVersion   = "Latest"
      outputVersion  = "3.0.0"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = ""
      runElevated    = false
    }
  },
  {
    name = "WindowsWorkstationV4"
    image = {
      definitionName = "WindowsWorkstation"
      sourceType     = "PlatformImage"
      customizeFile  = "customize.ps1"
      metadataFile   = "metadata.ps1"
      inputVersion   = "Latest"
      outputVersion  = "4.0.0"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                    // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                  // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = ""
      runElevated    = false
    }
  }
]

# Storage - https://docs.microsoft.com/en-us/azure/storage/
storage = {
  accountName        = "azimage"   // Name must be globally unique, lowercase alphanumeric
  accountType        = "StorageV2" // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
  accountRedundancy  = "LRS"       // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
  accountPerformance = "Standard"  // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
  containerName      = "builder"   // Storage container for Image Builder customization scripts
}

# Virtual Network - https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview
virtualNetwork = {
  name              = ""
  resourceGroupName = ""
}
