resourceGroupName = "ArtistAnywhere.Image" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

###############################################################################################
# Compute Gallery (https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) #
###############################################################################################

imageGallery = {
  name = "azrender"
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

#####################################################################################################
# Container Registry (https://learn.microsoft.com/zure/container-registry/container-registry-intro) #
#####################################################################################################

containerRegistry = {
  name = "azrender"
  sku  = "Premium"
}

#############################################################################################
# Image Builder (https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) #
#############################################################################################

imageTemplates = [
  {
    name = "LnxScheduler"
    image = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType = "Scheduler"
      machineSize = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform = [                 # GRID, AMD, CUDA and/or CUDA.OptiX
      ]
      outputVersion  = "0.0.0"
      timeoutMinutes = 120
      osDiskSizeGB   = 0
      renderEngines = [
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
      machineType = "Farm"
      machineSize = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform = [                         # GRID, AMD, CUDA and/or CUDA.OptiX
        "GRID"
      ]
      outputVersion  = "1.1.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 480
      renderEngines = [
        "PBRT",
        "Blender",
        # "Unreal",
        # "Unity"
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
      machineType = "Farm"
      machineSize = "Standard_HB120rs_v2" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform = [                     # GRID, AMD, CUDA and/or CUDA.OptiX
      ]
      outputVersion  = "1.0.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 480
      renderEngines = [
        "PBRT",
        "Blender"
      ]
    }
  },
  {
    name = "LnxArtist"
    image = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType = "Workstation"
      machineSize = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform = [                         # GRID, AMD, CUDA and/or CUDA.OptiX
        "GRID"
      ]
      outputVersion  = "2.0.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 512
      renderEngines = [
        "PBRT",
        "Blender",
        # "Unreal.PixelStream",
        # "Unity"
      ]
    }
  },
  {
    name = "WinScheduler"
    image = {
      definitionName = "WinScheduler"
      inputVersion   = "Latest"
    }
    build = {
      machineType = "Scheduler"
      machineSize = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform = [                 # GRID, AMD, CUDA and/or CUDA.OptiX
      ]
      outputVersion  = "0.0.0"
      timeoutMinutes = 180
      osDiskSizeGB   = 0
      renderEngines = [
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
      machineType = "Farm"
      machineSize = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform = [                         # GRID, AMD, CUDA and/or CUDA.OptiX
        "GRID"
      ]
      outputVersion  = "1.1.0"
      timeoutMinutes = 420
      osDiskSizeGB   = 480
      renderEngines = [
        "PBRT",
        "Blender",
        # "Unreal",
        # "Unity"
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
      machineType = "Farm"
      machineSize = "Standard_HB120rs_v2" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform = [                     # GRID, AMD, CUDA and/or CUDA.OptiX
      ]
      outputVersion  = "1.0.0"
      timeoutMinutes = 420
      osDiskSizeGB   = 480
      renderEngines = [
        "PBRT",
        "Blender"
      ]
    }
  },
  {
    name = "WinArtist"
    image = {
      definitionName = "WinArtist"
      inputVersion   = "Latest"
    }
    build = {
      machineType = "Workstation"
      machineSize = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuPlatform = [                         # GRID, AMD, CUDA and/or CUDA.OptiX
        "GRID"
      ]
      outputVersion  = "2.0.0"
      timeoutMinutes = 420
      osDiskSizeGB   = 512
      renderEngines = [
        "PBRT",
        "Blender",
        # "Unreal.PixelStream",
        # "Unity"
      ]
    }
  }
]

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}

managedIdentity = {
  name              = ""
  resourceGroupName = ""
}

keyVault = {
  name                 = ""
  resourceGroupName    = ""
  keyNameAdminUsername = ""
  keyNameAdminPassword = ""
}
