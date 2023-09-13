resourceGroupName = "ArtistAnywhere.Image" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

###############################################################################################
# Compute Gallery (https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) #
###############################################################################################

computeGallery = {
  name = "azstudio"
  imageDefinitions = [
    {
      name       = "Linux"
      type       = "Linux"
      generation = "V2"
      publisher  = "AlmaLinux"
      offer      = "AlmaLinux-x86_64"
      sku        = "9-Gen2"
      enablePlan = false
    },
    {
      name       = "WinServer"
      type       = "Windows"
      generation = "V2"
      publisher  = "MicrosoftWindowsServer"
      offer      = "WindowsServer"
      sku        = "2022-Datacenter-G2"
      enablePlan = false
    },
    {
      name       = "WinFarm"
      type       = "Windows"
      generation = "V2"
      publisher  = "MicrosoftWindowsDesktop"
      offer      = "Windows-10"
      sku        = "Win10-22H2-Pro-G2"
      enablePlan = false
    },
    {
      name       = "WinArtist"
      type       = "Windows"
      generation = "V2"
      publisher  = "MicrosoftWindowsDesktop"
      offer      = "Windows-11"
      sku        = "Win11-22H2-Pro"
      enablePlan = false
    }
  ]
}

#############################################################################################
# Image Builder (https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) #
#############################################################################################

imageTemplates = [
  {
    name = "LnxStorage"
    image = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Storage"
      machineSize    = "Standard_L8as_v3" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                 # NVIDIA or AMD
      outputVersion  = "0.0.0"
      timeoutMinutes = 120
      osDiskSizeGB   = 512
      batchService   = false
      renderEngines = [
      ]
    }
  },
  {
    name = "LnxScheduler"
    image = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                 # NVIDIA or AMD
      outputVersion  = "1.0.0"
      timeoutMinutes = 120
      osDiskSizeGB   = 512
      batchService   = false
      renderEngines = [
      ]
    }
  },
  {
    name = "LnxFarmCPU"
    image = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_D96as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                  # NVIDIA or AMD
      outputVersion  = "2.0.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 480
      batchService   = false
      renderEngines = [
        "PBRT",
        "Blender",
        "MoonRay"
      ]
    }
  },
  {
    name = "LnxFarmGPU"
    image = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "NVIDIA"                  # NVIDIA or AMD
      outputVersion  = "2.1.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 480
      batchService   = false
      renderEngines = [
        "PBRT",
        "Blender",
        "MoonRay",
        "Unreal"
      ]
    }
  },
  {
    name = "LnxArtistNVIDIA"
    image = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "NVIDIA"                  # NVIDIA or AMD
      outputVersion  = "3.0.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 1024
      batchService   = false
      renderEngines = [
        "PBRT",
        "Blender",
        "MoonRay",
        "Unreal+PixelStream"
      ]
    }
  },
  # {
  #   name = "LnxArtistAMD"
  #   image = {
  #     definitionName = "Linux"
  #     inputVersion   = "Latest"
  #   }
  #   build = {
  #     machineType    = "Workstation"
  #     machineSize    = "Standard_NG32ads_V620_v1" # https://learn.microsoft.com/azure/virtual-machines/sizes
  #     gpuProvider    = "AMD"                      # NVIDIA or AMD
  #     outputVersion  = "3.1.0"
  #     timeoutMinutes = 240
  #     osDiskSizeGB   = 1024
  #     batchService   = false
  #     renderEngines = [
  #       "PBRT",
  #       "Blender",
  #       "MoonRay",
  #       "Unreal+PixelStream"
  #     ]
  #   }
  # },
  {
    name = "WinScheduler"
    image = {
      definitionName = "WinServer"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                 # NVIDIA or AMD
      outputVersion  = "1.0.0"
      timeoutMinutes = 180
      osDiskSizeGB   = 512
      batchService   = false
      renderEngines = [
      ]
    }
  },
  {
    name = "WinFarmCPU"
    image = {
      definitionName = "WinFarm"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_D96as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                  # NVIDIA or AMD
      outputVersion  = "2.0.0"
      timeoutMinutes = 420
      osDiskSizeGB   = 480
      batchService   = false
      renderEngines = [
        "PBRT",
        "Blender"
      ]
    }
  },
  {
    name = "WinFarmGPU"
    image = {
      definitionName = "WinFarm"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                        # NVIDIA or AMD
      outputVersion  = "2.1.0"
      timeoutMinutes = 420
      osDiskSizeGB   = 480
      batchService   = false
      renderEngines = [
        "PBRT",
        "Blender",
        "Unreal"
      ]
   }
  },
  {
    name = "WinArtistNVIDIA"
    image = {
      definitionName = "WinArtist"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "NVIDIA"                  # NVIDIA or AMD
      outputVersion  = "3.0.0"
      timeoutMinutes = 420
      osDiskSizeGB   = 1024
      batchService   = false
      renderEngines = [
        "PBRT",
        "Blender",
        "Unreal+PixelStream"
      ]
    }
  },
  # {
  #   name = "WinArtistAMD"
  #   image = {
  #     definitionName = "WinArtist"
  #     inputVersion   = "Latest"
  #   }
  #   build = {
  #     machineType    = "Workstation"
  #     machineSize    = "Standard_NG32ads_V620_v1" # https://learn.microsoft.com/azure/virtual-machines/sizes
  #     gpuProvider    = "AMD"                      # NVIDIA or AMD
  #     outputVersion  = "3.1.0"
  #     timeoutMinutes = 420
  #     osDiskSizeGB   = 1024
  #     batchService   = false
  #     renderEngines = [
  #       "PBRT",
  #       "Blender",
  #       "Unreal+PixelStream"
  #     ]
  #   }
  # }
]

binStorage = {
  host = ""
  auth = ""
}
