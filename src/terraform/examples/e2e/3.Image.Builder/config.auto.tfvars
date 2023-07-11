resourceGroupName = "ArtistAnywhere.Image" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

###############################################################################################
# Compute Gallery (https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) #
###############################################################################################

imageGallery = {
  name = "azstudio"
  imageDefinitions = [
    {
      name       = "Linux"
      type       = "Linux"
      generation = "V2"
      publisher  = "CIQ"
      offer      = "Rocky"
      sku        = "Rocky-8-6-Free"
    },
    {
      name       = "WinServer"
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
  name = ""
  sku  = "Premium"
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
      machineSize    = "Standard_L8s_v3" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                # NVIDIA or AMD
      outputVersion  = "0.0.0"
      timeoutMinutes = 120
      osDiskSizeGB   = 64
      renderEngines = [
      ]
      customize = [
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
      machineSize    = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                # NVIDIA or AMD
      outputVersion  = "1.0.0"
      timeoutMinutes = 120
      osDiskSizeGB   = 512
      renderEngines = [
      ]
      customize = [
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
      machineSize    = "Standard_D48ads_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                   # NVIDIA or AMD
      outputVersion  = "2.0.0"
      timeoutMinutes = 240
      osDiskSizeGB   = 1024
      renderEngines = [
        "PBRT",
        "Blender",
        # "MoonRay"
      ]
      customize = [
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
      osDiskSizeGB   = 1024
      renderEngines = [
        "PBRT",
        "Blender",
        # "MoonRay",
        "Unreal"
      ]
      customize = [
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
      renderEngines = [
        "PBRT",
        "Blender",
        # "MoonRay",
        "Unreal+PixelStream"
      ]
      customize = [
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
  #     renderEngines = [
  #       "PBRT",
  #       "Blender",
  #       # "MoonRay",
  #       "Unreal+PixelStream"
  #     ]
  #     customize = [
  #     ]
  #   }
  # },
  {
    name = "WinDirectory"
    image = {
      definitionName = "WinServer"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "DomainController"
      machineSize    = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                # NVIDIA or AMD
      outputVersion  = "0.0.0"
      timeoutMinutes = 180
      osDiskSizeGB   = 512
      renderEngines = [
      ]
      customize = [
        "$domainName = 'artist.studio'",
        "$domainPassword = 'P@ssword1234'",
        "Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools",
        "Import-Module ADDSDeployment",
        "Install-ADDSForest -DomainName $domainName -SafeModeAdministratorPassword $domainPassword -Force -NoRebootOnCompletion"
      ]
    }
  },
  {
    name = "WinScheduler"
    image = {
      definitionName = "WinServer"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Scheduler"
      machineSize    = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                # NVIDIA or AMD
      outputVersion  = "1.0.0"
      timeoutMinutes = 180
      osDiskSizeGB   = 512
      renderEngines = [
      ]
      customize = [
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
      machineSize    = "Standard_D48ads_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                   # NVIDIA or AMD
      outputVersion  = "2.0.0"
      timeoutMinutes = 420
      osDiskSizeGB   = 1024
      renderEngines = [
        "PBRT",
        "Blender"
      ]
      customize = [
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
      osDiskSizeGB   = 1024
      renderEngines = [
        "PBRT",
        "Blender",
        "Unreal"
      ]
      customize = [
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
      renderEngines = [
        "PBRT",
        "Blender",
        "Unreal+PixelStream"
      ]
      customize = [
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
  #     renderEngines = [
  #       "PBRT",
  #       "Blender",
  #       "Unreal+PixelStream"
  #     ]
  #     customize = [
  #     ]
  #   }
  # }
]

servicePassword = "P@ssword1234"

binStorage = {
  host = ""
  auth = ""
}

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
