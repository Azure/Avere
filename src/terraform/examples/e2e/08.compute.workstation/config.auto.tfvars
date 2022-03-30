resourceGroupName = "ArtistAnywhere.Workstation"

# Virtual Machines (https://docs.microsoft.com/en-us/azure/virtual-machines)
virtualMachines = [
  {
    name        = "LnxArtist"
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/3.0.0"
    machineSize = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type        = "Linux"
      licenseType = ""
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    networkInterface = {
      enableAcceleratedNetworking = false
    }
    adminLogin = {
      userName     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0",
          "azartist1.blob.core.windows.net:/azartist1/show /mnt/show nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/4.0.0"
    machineSize = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    networkInterface = {
      enableAcceleratedNetworking = false
    }
    adminLogin = {
      userName     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0",
          "azartist1.blob.core.windows.net:/azartist1/show /mnt/show nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/5.0.0"
    machineSize = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    networkInterface = {
      enableAcceleratedNetworking = false
    }
    adminLogin = {
      userName     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0",
          "azartist1.blob.core.windows.net:/azartist1/show /mnt/show nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = "WinArtist"
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinArtist/versions/3.0.0"
    machineSize = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    networkInterface = {
      enableAcceleratedNetworking = false
    }
    adminLogin = {
      userName     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:",
          "mount -o anon nolock \\\\azartist1.blob.core.windows.net\\azartist1\\show W:"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinArtist/versions/4.0.0"
    machineSize = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    networkInterface = {
      enableAcceleratedNetworking = false
    }
    adminLogin = {
      userName     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:",
          "mount -o anon nolock \\\\azartist1.blob.core.windows.net\\azartist1\\show W:"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinArtist/versions/5.0.0"
    machineSize = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    networkInterface = {
      enableAcceleratedNetworking = false
    }
    adminLogin = {
      userName     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:",
          "mount -o anon nolock \\\\azartist1.blob.core.windows.net\\azartist1\\show W:"
        ]
        teradiciLicenseKey = ""
      }
    }
  }
]

# Virtual Network (https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
