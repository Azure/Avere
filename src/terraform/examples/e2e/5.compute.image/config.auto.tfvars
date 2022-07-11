resourceGroupName = "ArtistAnywhere.Image"

# Compute Gallery (https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries)
imageGalleryName = "Gallery"
imageDefinitions = [
  {
    name       = "Linux"
    type       = "Linux"
    generation = "V2"
    publisher  = "OpenLogic"
    offer      = "CentOS"
    sku        = "7_9-Gen2"
  },
  {
    name       = "WinScheduler"
    type       = "Windows"
    generation = "V2"
    publisher  = "MicrosoftWindowsServer"
    offer      = "WindowsServer"
    sku        = "2022-Datacenter-G2"
  },
  {
    name       = "WinFarm"
    type       = "Windows"
    generation = "V2"
    publisher  = "MicrosoftWindowsDesktop"
    offer      = "Windows-10"
    sku        = "Win10-21H2-Pro-G2"
  },
  {
    name       = "WinArtist"
    type       = "Windows"
    generation = "V2"
    publisher  = "MicrosoftWindowsDesktop"
    offer      = "Windows-11"
    sku        = "Win11-21H2-Pro"
  }
]

# Image Builder (https://docs.microsoft.com/azure/virtual-machines/image-builder-overview)
imageTemplates = [
  {
    name = "LnxScheduler"
    image = {
      definitionName   = "Linux"
      sourceType       = "PlatformImage"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      subnetName     = "Farm"
      machineSize    = "Standard_D8s_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                 // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 120               // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "0.0.0"
      runElevated    = false
      renderEngines  = []
    }
  },
  {
    name = "LnxFarm"
    image = {
      definitionName   = "Linux"
      sourceType       = "PlatformImage"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      subnetName     = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 480                   // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 240                   // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "1.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        # "Unreal",
        # "Maya",
        # "Houdini"
      ]
    }
  },
  {
    name = "LnxArtistV3"
    image = {
      definitionName   = "Linux"
      sourceType       = "PlatformImage"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NC16as_T4_v3" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 480                     // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 240                     // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "3.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        # "Unreal",
        # "Maya",
        # "Houdini"
      ]
    }
  },
  {
    name = "LnxArtistV4"
    image = {
      definitionName   = "Linux"
      sourceType       = "PlatformImage"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV32as_v4" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 480                  // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 240                  // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "4.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        # "Unreal",
        # "Maya",
        # "Houdini"
      ]
    }
  },
  # {
  #   name = "LnxArtistV5"
  #   image = {
  #     definitionName   = "Linux"
  #     sourceType       = "PlatformImage"
  #     customizeScript  = "customize.ps1"
  #     terminateScript1 = "terminate.sh"
  #     terminateScript2 = "onTerminate.sh"
  #     inputVersion     = "Latest"
  #   }
  #   build = {
  #     subnetName     = "Workstation"
  #     machineSize    = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
  #     osDiskSizeGB   = 480                       // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
  #     timeoutMinutes = 240                       // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
  #     outputVersion  = "5.0.0"
  #     runElevated    = false
  #     renderEngines  = [
  #       "Blender",
  #       "PBRT",
  #       # "Unreal",
  #       # "Maya",
  #       # "Houdini"
  #     ]
  #   }
  # },
  {
    name = "WinScheduler"
    image = {
      definitionName   = "WinScheduler"
      sourceType       = "PlatformImage"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      subnetName     = "Farm"
      machineSize    = "Standard_D8s_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 0                 // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 180               // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "0.0.0"
      runElevated    = true
      renderEngines  = []
    }
  },
  {
    name = "WinFarm"
    image = {
      definitionName   = "WinFarm"
      sourceType       = "PlatformImage"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      subnetName     = "Farm"
      machineSize    = "Standard_HB120rs_v2" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 480                   // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 480                   // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "1.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        # "Unreal",
        # "Maya",
        # "3DSMax",
        # "Houdini"
      ]
    }
  },
  {
    name = "WinArtistV3"
    image = {
      definitionName   = "WinArtist"
      sourceType       = "PlatformImage"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NC16as_T4_v3" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 480                     // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 480                     // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "3.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        # "Unreal",
        # "Maya",
        # "3DSMax",
        # "Houdini"
      ]
    }
  },
  {
    name = "WinArtistV4"
    image = {
      definitionName   = "WinArtist"
      sourceType       = "PlatformImage"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      subnetName     = "Workstation"
      machineSize    = "Standard_NV32as_v4" // https://docs.microsoft.com/azure/virtual-machines/sizes
      osDiskSizeGB   = 480                  // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
      timeoutMinutes = 480                  // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
      outputVersion  = "4.0.0"
      runElevated    = false
      renderEngines  = [
        "Blender",
        "PBRT",
        # "Unreal",
        # "Maya",
        # "3DSMax",
        # "Houdini"
      ]
    }
  },
  # {
  #   name = "WinArtistV5"
  #   image = {
  #     definitionName   = "WinArtist"
  #     sourceType       = "PlatformImage"
  #     customizeScript  = "customize.ps1"
  #     terminateScript1 = "terminate.ps1"
  #     terminateScript2 = "onTerminate.ps1"
  #     inputVersion     = "Latest"
  #   }
  #   build = {
  #     subnetName     = "Workstation"
  #     machineSize    = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
  #     osDiskSizeGB   = 480                       // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#osdisksizegb
  #     timeoutMinutes = 480                       // https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-json#properties-buildtimeoutinminutes
  #     outputVersion  = "4.0.0"
  #     runElevated    = false
  #     renderEngines  = [
  #       "Blender",
  #       "PBRT",
  #       # "Unreal",
  #       # "Maya",
  #       # "3DSMax",
  #       # "Houdini"
  #     ]
  #   }
  # }
]

# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name              = ""
  resourceGroupName = ""
}