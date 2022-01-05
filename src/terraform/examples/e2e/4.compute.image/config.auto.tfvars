resourceGroupName = "AzureRender.Image"

# Shared Image Gallery - https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries
imageGalleryName = "Gallery"
imageDefinitions = [
  {
    name       = "LinuxFarm"
    type       = "Linux"
    generation = "V2"
    publisher  = "OpenLogic"
    offer      = "CentOS"
    sku        = "7_8-Gen2"
  },
  {
    name       = "LinuxWorkstation"
    type       = "Linux"
    generation = "V2"
    publisher  = "OpenLogic"
    offer      = "CentOS"
    sku        = "7_9-Gen2"
  },
  {
    name       = "WindowsScheduler"
    type       = "Windows"
    generation = "V2"
    publisher  = "MicrosoftWindowsServer"
    offer      = "WindowsServer"
    sku        = "2022-Datacenter-G2"
  },
  {
    name       = "WindowsFarm"
    type       = "Windows"
    generation = "V2"
    publisher  = "MicrosoftWindowsDesktop"
    offer      = "Windows-10"
    sku        = "Win10-21H2-Pro-G2"
  },
  {
    name       = "WindowsWorkstation"
    type       = "Windows"
    generation = "V2"
    publisher  = "MicrosoftWindowsDesktop"
    offer      = "Windows-11"
    sku        = "Win11-21H2-Pro"
  }
]

# Image Builder - https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview
imageTemplates = [
  {
    name = "LinuxScheduler"
    image = {
      definitionName = "LinuxFarm"
      sourceType     = "PlatformImage"
      customScript   = "customize.sh"
      inputVersion   = "Latest"
      outputVersion  = "10.0.0"
    }
    build = {
      subnetName     = "Scheduler"
      machineSize    = "Standard_D8s_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120               // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "dbuser"
    }
  },
  {
    name = "LinuxFarm"
    image = {
      definitionName = "LinuxFarm"
      sourceType     = "PlatformImage"
      customScript   = "customize.sh"
      inputVersion   = "Latest"
      outputVersion  = "1.0.0"
    }
    build = {
      subnetName     = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "azuser"
    }
  },
  {
    name = "LinuxWorkstationV3"
    image = {
      definitionName = "LinuxWorkstation"
      sourceType     = "PlatformImage"
      customScript   = "customize.sh"
      inputVersion   = "Latest"
      outputVersion  = "3.0.0"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "azuser"
    }
  },
  {
    name = "LinuxWorkstationV4"
    image = {
      definitionName = "LinuxWorkstation"
      sourceType     = "PlatformImage"
      customScript   = "customize.sh"
      inputVersion   = "Latest"
      outputVersion  = "4.0.0"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                    // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                  // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "azuser"
    }
  },
  {
    name = "WindowsScheduler"
    image = {
      definitionName = "WindowsScheduler"
      sourceType     = "PlatformImage"
      customScript   = "customize.ps1"
      inputVersion   = "Latest"
      outputVersion  = "10.0.0"
    }
    build = {
      subnetName     = "Scheduler"
      machineSize    = "Standard_D8s_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120               // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "dbuser"
    }
  },
  {
    name = "WindowsFarm"
    image = {
      definitionName = "WindowsFarm"
      sourceType     = "PlatformImage"
      customScript   = "customize.ps1"
      inputVersion   = "Latest"
      outputVersion  = "1.0.0"
    }
    build = {
      subnetName     = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                     // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "azuser"
    }
  },
  {
    name = "WindowsWorkstationV3"
    image = {
      definitionName = "WindowsWorkstation"
      sourceType     = "PlatformImage"
      customScript   = "customize.ps1"
      inputVersion   = "Latest"
      outputVersion  = "3.0.0"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                   // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                 // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "azuser"
    }
  },
  {
    name = "WindowsWorkstationV4"
    image = {
      definitionName = "WindowsWorkstation"
      sourceType     = "PlatformImage"
      customScript   = "customize.ps1"
      inputVersion   = "Latest"
      outputVersion  = "4.0.0"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                    // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120                  // https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      userName       = "azuser"
    }
  }
]

# Virtual Network - https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview
virtualNetwork = {
  name              = ""
  resourceGroupName = ""
}
