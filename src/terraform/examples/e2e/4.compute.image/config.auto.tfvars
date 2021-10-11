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
    name                = "LinuxFarm"
    imageDefinitionName = "LinuxFarm"
    imageSourceType     = "PlatformImage"
    imageScriptFile     = "customize.sh"
    imageSkuVersion     = "Latest"
    imageOutputVersion  = "1.0.0"
    buildTimeoutMinutes = 60
    machineProfile = {                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vmprofile
      sizeSku      = "Standard_HB120rs_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      subnetName   = "Farm"                // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vnetconfig
      osDiskSizeGB = 0                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
    }
  },
  {
    name                = "LinuxWorkstationV3"
    imageDefinitionName = "LinuxWorkstation"
    imageSourceType     = "PlatformImage"
    imageScriptFile     = "customize.sh"
    imageSkuVersion     = "Latest"
    imageOutputVersion  = "1.0.0"
    buildTimeoutMinutes = 60
    machineProfile = {                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vmprofile
      sizeSku      = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      subnetName   = "Workstation"       // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vnetconfig
      osDiskSizeGB = 0                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
    }
  },
  {
    name                = "LinuxWorkstationV4"
    imageDefinitionName = "LinuxWorkstation"
    imageSourceType     = "PlatformImage"
    imageScriptFile     = "customize.sh"
    imageSkuVersion     = "Latest"
    imageOutputVersion  = "1.0.0"
    buildTimeoutMinutes = 60
    machineProfile = {                    // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vmprofile
      sizeSku      = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      subnetName   = "Workstation"        // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vnetconfig
      osDiskSizeGB = 0                    // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
    }
  },
  {
    name                = "WindowsFarm"
    imageDefinitionName = "WindowsFarm"
    imageSourceType     = "PlatformImage"
    imageScriptFile     = "customize.ps1"
    imageSkuVersion     = "Latest"
    imageOutputVersion  = "1.0.0"
    buildTimeoutMinutes = 60
    machineProfile = {                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vmprofile
      sizeSku      = "Standard_HB120rs_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      subnetName   = "Farm"                // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vnetconfig
      osDiskSizeGB = 0                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
    }
  },
  {
    name                = "WindowsWorkstationV3"
    imageDefinitionName = "WindowsWorkstation"
    imageSourceType     = "PlatformImage"
    imageScriptFile     = "customize.ps1"
    imageSkuVersion     = "Latest"
    imageOutputVersion  = "1.0.0"
    buildTimeoutMinutes = 60
    machineProfile = {                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vmprofile
      sizeSku      = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      subnetName   = "Workstation"       // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vnetconfig
      osDiskSizeGB = 0                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
    }
  },
  {
    name                = "WindowsWorkstationV4"
    imageDefinitionName = "WindowsWorkstation"
    imageSourceType     = "PlatformImage"
    imageScriptFile     = "customize.ps1"
    imageSkuVersion     = "Latest"
    imageOutputVersion  = "1.0.0"
    buildTimeoutMinutes = 60
    machineProfile = {                    // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vmprofile
      sizeSku      = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      subnetName   = "Workstation"        // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#vnetconfig
      osDiskSizeGB = 0                    // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
    }
  }
]

# Storage - https://docs.microsoft.com/en-us/azure/storage/
storage = {
  accountName        = "mediaimage" // Name must be globally unique, lowercase alphanumeric
  accountType        = "StorageV2"  // https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
  accountRedundancy  = "LRS"        // https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
  accountPerformance = "Standard"   // https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-performance-tiers
  containerName      = "builder"    // Storage container for Image Builder customization scripts
}
