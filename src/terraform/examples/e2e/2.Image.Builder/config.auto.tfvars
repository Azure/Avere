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
        "cd /usr/local/bin",
        "dnf -y install jq bc lsof",
        "binStorageHost=https://azstudio.blob.core.windows.net/bin",
        "binStorageAuth='?sv=2021-10-04&st=2022-01-01T00%3A00%3A00Z&se=9999-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=SyE2RuK0C7M9nNQSJfiw4SenqqV8O6DYulr24ZJapFw%3D'",
        "dnf -y install gcc gcc-c++ perl elfutils-libelf-devel # openssl-devel bison flex",
        "installFile=kernel-devel-4.18.0-372.16.1.el8_6.0.1.x86_64.rpm",
        "downloadUrl=$binStorageHost/Linux/Rocky/$installFile$binStorageAuth",
        "curl -o $installFile -L $downloadUrl",
        "rpm -i $installFile",
        "dnf -y install kernel-rpm-macros rpm-build python3-devel gcc-gfortran libtool pciutils tcl tk # tcsh",
        "installFile=MLNX_OFED_LINUX-23.04-0.5.3.3-rhel8.6-x86_64.tgz",
        "downloadUrl=$binStorageHost/NVIDIA/OFED/$installFile$binStorageAuth",
        "curl -o $installFile -L $downloadUrl",
        "tar -xzf $installFile",
        "./MLNX_OFED*/mlnxofedinstall --without-fw-update --add-kernel-support --skip-repo --force 2>&1 | tee mellanox-ofed.log",
        "rpm --import https://packages.microsoft.com/keys/microsoft.asc",
        "dnf -y install https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm",
        "dnf -y install azure-cli 2>&1 | tee azure-cli.log"
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
        # "MoonRay",
        "Unreal"
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
    name = "LnxArtistCPU"
    image = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_D32ads_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                   # NVIDIA or AMD
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
  {
    name = "LnxArtistGPU"
    image = {
      definitionName = "Linux"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "NVIDIA"                  # NVIDIA or AMD
      outputVersion  = "3.1.0"
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
  {
    name = "WinDomain"
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
        "Blender",
        "Unreal"
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
    name = "WinArtistCPU"
    image = {
      definitionName = "WinArtist"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_D32ads_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = ""                   # NVIDIA or AMD
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
  {
    name = "WinArtistGPU"
    image = {
      definitionName = "WinArtist"
      inputVersion   = "Latest"
    }
    build = {
      machineType    = "Workstation"
      machineSize    = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      gpuProvider    = "NVIDIA"                  # NVIDIA or AMD
      outputVersion  = "3.1.0"
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
  }
]

servicePassword = "P@ssword1234"

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
