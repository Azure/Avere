resourceGroupName = "ArtistAnywhere.Image" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

###############################################################################################
# Compute Gallery (https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) #
###############################################################################################

computeGallery = {
  name = "azstudio"
  imageDefinition = {
    Linux = {
      type       = "Linux"
      generation = "V2"
      publisher  = "AlmaLinux"
      offer      = "AlmaLinux-x86_64"
      sku        = "9-Gen2"
    }
    WinServer = {
      type       = "Windows"
      generation = "V2"
      publisher  = "MicrosoftWindowsServer"
      offer      = "WindowsServer"
      sku        = "2022-Datacenter-G2"
    }
    WinFarm = {
      type       = "Windows"
      generation = "V2"
      publisher  = "MicrosoftWindowsDesktop"
      offer      = "Windows-10"
      sku        = "Win10-22H2-Pro-G2"
    }
    WinArtist = {
      type       = "Windows"
      generation = "V2"
      publisher  = "MicrosoftWindowsDesktop"
      offer      = "Windows-11"
      sku        = "Win11-22H2-Pro"
    }
  }
}

#############################################################################################
# Image Builder (https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) #
#############################################################################################

imageTemplates = [
  {
    name = "LnxStorageCPU"
    source = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Storage"
      machineSize    = "Standard_L8as_v3" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                 # NVIDIA or AMD
      outputVersion  = "0.0.0"
      timeoutMinutes = 120
      osDiskSizeGB   = 0
      renderEngines = [
      ]
    }
  },
  {
    name = "LnxStorageGPU"
    source = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Storage"
      machineSize    = "Standard_NG8ads_V620_v1" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "AMD"                     # NVIDIA or AMD
      outputVersion  = "0.1.0"
      timeoutMinutes = 120
      osDiskSizeGB   = 0
      renderEngines = [
      ]
    }
  },
  {
    name = "LnxScheduler"
    source = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                 # NVIDIA or AMD
      outputVersion  = "1.0.0"
      timeoutMinutes = 120
      osDiskSizeGB   = 0
      renderEngines = [
      ]
    }
  },
  {
    name = "LnxFarmCPU"
    source = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_D96as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                  # NVIDIA or AMD
      outputVersion  = "2.0.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 360
      renderEngines = [
        "PBRT",
        "Blender",
        "MoonRay"
      ]
    }
  },
  {
    name = "LnxFarmGPU"
    source = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "NVIDIA"                  # NVIDIA or AMD
      outputVersion  = "2.1.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 360
      renderEngines = [
        "PBRT",
        "Blender",
        "MoonRay",
        #"Unreal"
      ]
    }
  },
  {
    name = "LnxArtistNVIDIA"
    source = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "NVIDIA"                  # NVIDIA or AMD
      outputVersion  = "3.0.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 360
      renderEngines = [
        "PBRT",
        "Blender",
        "MoonRay",
        #"Unreal+PixelStream"
      ]
    }
  },
  {
    name = "LnxArtistAMD"
    source = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NG32ads_V620_v1" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "AMD"                      # NVIDIA or AMD
      outputVersion  = "3.1.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 360
      renderEngines = [
        "PBRT",
        "Blender",
        "MoonRay",
        #"Unreal+PixelStream"
      ]
    }
  },
  {
    name = "WinScheduler"
    source = {
      definitionName = "WinServer"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                 # NVIDIA or AMD
      outputVersion  = "1.0.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 0
      renderEngines = [
      ]
    }
  },
  {
    name = "WinFarmCPU"
    source = {
      definitionName = "WinFarm"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_D96as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                  # NVIDIA or AMD
      outputVersion  = "2.0.0"
      timeoutMinutes = 360
      osDiskSizeGB   = 360
      renderEngines = [
        "PBRT",
        "Blender"
      ]
    }
  },
  {
    name = "WinFarmGPU"
    source = {
      definitionName = "WinFarm"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Farm"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                        # NVIDIA or AMD
      outputVersion  = "2.1.0"
      timeoutMinutes = 360
      osDiskSizeGB   = 360
      renderEngines = [
        "PBRT",
        "Blender",
        #"Unreal"
      ]
   }
  },
  {
    name = "WinArtistNVIDIA"
    source = {
      definitionName = "WinArtist"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "NVIDIA"                  # NVIDIA or AMD
      outputVersion  = "3.0.0"
      timeoutMinutes = 360
      osDiskSizeGB   = 360
      renderEngines = [
        "PBRT",
        "Blender",
        #"Unreal+PixelStream"
      ]
    }
  },
  {
    name = "WinArtistAMD"
    source = {
      definitionName = "WinArtist"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NG32ads_V620_v1" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "AMD"                      # NVIDIA or AMD
      outputVersion  = "3.1.0"
      timeoutMinutes = 360
      osDiskSizeGB   = 360
      renderEngines = [
        "PBRT",
        "Blender",
        #"Unreal+PixelStream"
      ]
    }
  }
]

binStorage = {
  host = ""
  auth = ""
}
