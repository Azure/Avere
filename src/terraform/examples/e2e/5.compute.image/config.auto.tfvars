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
      publisher  = "AlmaLinux"
      offer      = "AlmaLinux"
      sku        = "9-Gen2"
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
      definitionName   = "Linux"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 0
      timeoutMinutes = 120
      outputVersion  = "0.0.0"
      renderManager  = "Deadline" # RoyalRender or Deadline
      renderEngines  = []
    }
  },
  {
    name = "LnxFarm"
    image = {
      definitionName   = "Linux"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_HB120rs_v2" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                    # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 480
      timeoutMinutes = 240
      outputVersion  = "1.0.0"
      renderManager  = "Deadline" # RoyalRender or Deadline
      renderEngines  = [
        "Blender",
        "PBRT"
        # "Unity",
        # "Unreal"
      ]
    }
  },
  {
    name = "LnxArtist"
    image = {
      definitionName   = "Linux"
      customizeScript  = "customize.sh"
      terminateScript1 = "terminate.sh"
      terminateScript2 = "onTerminate.sh"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = ["GRID"]                  # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 512
      timeoutMinutes = 240
      outputVersion  = "2.0.0"
      renderManager  = "Deadline" # RoyalRender or Deadline
      renderEngines  = [
        "Blender",
        "PBRT"
        # "Unity",
        # "Unreal",
        # "Unreal.PixelStream"
      ]
    }
  },
  {
    name = "WinScheduler"
    image = {
      definitionName   = "WinScheduler"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 0
      timeoutMinutes = 180
      outputVersion  = "0.0.0"
      renderManager  = "Deadline" # RoyalRender or Deadline
      renderEngines  = []
    }
  },
  {
    name = "WinFarm"
    image = {
      definitionName   = "WinFarm"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_HB120rs_v2" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = []                    # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 480
      timeoutMinutes = 420
      outputVersion  = "1.0.0"
      renderManager  = "Deadline" # RoyalRender or Deadline
      renderEngines  = [
        "Blender",
        "PBRT"
        # "Unity",
        # "Unreal"
      ]
    }
  },
  {
    name = "WinArtist"
    image = {
      definitionName   = "WinArtist"
      customizeScript  = "customize.ps1"
      terminateScript1 = "terminate.ps1"
      terminateScript2 = "onTerminate.ps1"
      inputVersion     = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform    = ["GRID"]                  # GRID, CUDA and/or CUDA.OptiX
      osDiskSizeGB   = 512
      timeoutMinutes = 420
      outputVersion  = "2.0.0"
      renderManager  = "Deadline" # RoyalRender or Deadline
      renderEngines  = [
        "Blender",
        "PBRT"
        # "Unity",
        # "Unreal",
        # "Unreal.PixelStream"
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