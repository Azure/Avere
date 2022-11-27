resourceGroupName = "ArtistAnywhere.Image"

###############################################################################################
# Compute Gallery (https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) #
###############################################################################################

imageGallery = {
  name = "Gallery"
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
      sku        = "Win10-22H2-Pro-G2"
    },
    {
      name       = "WinArtist"
      type       = "Windows"
      generation = "V2"
      publisher  = "MicrosoftWindowsDesktop"
      offer      = "Windows-11"
      sku        = "Win11-22H2-Pro"
    }
  ]
}

#############################################################################################
# Image Builder (https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) #
#############################################################################################

imageTemplates = [
  {
    name = "LnxScheduler"
    image = {
      definitionName  = "Linux"
      customizeScript = "customize.sh"
      terminateScript = "onTerminate.sh"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 0
      timeoutMinutes = 120
      outputVersion  = "0.0.0"
      renderEngines  = []
    }
  },
  {
    name = "LnxFarm1"
    image = {
      definitionName  = "Linux"
      customizeScript = "customize.sh"
      terminateScript = "onTerminate.sh"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_HB120rs_v2" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                    # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 480
      timeoutMinutes = 240
      outputVersion  = "1.0.0"
      renderEngines  = [
        "Blender",
        "PBRT"
      ]
    }
  },
  {
    name = "LnxFarm2"
    image = {
      definitionName  = "Linux"
      customizeScript = "customize.sh"
      terminateScript = "onTerminate.sh"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_HB120rs_v2" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                    # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 480
      timeoutMinutes = 240
      outputVersion  = "1.1.0"
      renderEngines  = [
        "Blender",
        "PBRT",
        "Unity",
        "Unreal"
      ]
    }
  },
  {
    name = "LnxArtist1"
    image = {
      definitionName  = "Linux"
      customizeScript = "customize.sh"
      terminateScript = "onTerminate.sh"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = ["GRID"]                  # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 512
      timeoutMinutes = 240
      outputVersion  = "2.0.0"
      renderEngines  = [
        "Blender",
        "PBRT"
      ]
    }
  },
  {
    name = "LnxArtist2"
    image = {
      definitionName  = "Linux"
      customizeScript = "customize.sh"
      terminateScript = "onTerminate.sh"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = ["GRID"]                  # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 512
      timeoutMinutes = 240
      outputVersion  = "2.1.0"
      renderEngines  = [
        "Blender",
        "PBRT",
        "Unity",
        "Unreal.PixelStream"
      ]
    }
  },
  {
    name = "WinScheduler"
    image = {
      definitionName  = "WinScheduler"
      customizeScript = "customize.ps1"
      terminateScript = "onTerminate.ps1"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 0
      timeoutMinutes = 180
      outputVersion  = "0.0.0"
      renderEngines  = []
    }
  },
  {
    name = "WinFarm1"
    image = {
      definitionName  = "WinFarm"
      customizeScript = "customize.ps1"
      terminateScript = "onTerminate.ps1"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_HB120rs_v2" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                    # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 480
      timeoutMinutes = 420
      outputVersion  = "1.0.0"
      renderEngines  = [
        "Blender",
        "PBRT"
      ]
    }
  },
  {
    name = "WinFarm2"
    image = {
      definitionName  = "WinFarm"
      customizeScript = "customize.ps1"
      terminateScript = "onTerminate.ps1"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_HB120rs_v2" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                    # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 480
      timeoutMinutes = 420
      outputVersion  = "1.1.0"
      renderEngines  = [
        "Blender",
        "PBRT",
        "Unity",
        "Unreal"
      ]
    }
  },
  {
    name = "WinArtist1"
    image = {
      definitionName  = "WinArtist"
      customizeScript = "customize.ps1"
      terminateScript = "onTerminate.ps1"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = ["GRID"]                  # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 512
      timeoutMinutes = 420
      outputVersion  = "2.0.0"
      renderEngines  = [
        "Blender",
        "PBRT"
      ]
    }
  },
  {
    name = "WinArtist2"
    image = {
      definitionName  = "WinArtist"
      customizeScript = "customize.ps1"
      terminateScript = "onTerminate.ps1"
      inputVersion    = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = ["GRID"]                  # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 512
      timeoutMinutes = 420
      outputVersion  = "2.1.0"
      renderEngines  = [
        "Blender",
        "PBRT",
        "Unity",
        "Unreal.PixelStream"
      ]
    }
  }
]

#######################################################################
# Optional resource dependency configuration for existing deployments #
#######################################################################

computeNetwork = {
  name              = ""
  resourceGroupName = ""
}
