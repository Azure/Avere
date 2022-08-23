resourceGroupName = "ArtistAnywhere.Workstation"

# Virtual Machines (https://docs.microsoft.com/azure/virtual-machines)
virtualMachines = [
  {
    name        = "LnxArtist"
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/3.0.0"
    machineSize = "Standard_NC16as_T4_v3" // https://docs.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type        = "Linux"
      licenseType = ""
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0",
          "cache.artist.studio:/mnt/show/workstation /mnt/show nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/4.0.0"
    machineSize = "Standard_NV32as_v4" // https://docs.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0",
          "cache.artist.studio:/mnt/show/workstation /mnt/show nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/5.0.0"
    machineSize = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0",
          "cache.artist.studio:/mnt/show/workstation /mnt/show nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = "WinArtist"
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinArtist/versions/3.0.0"
    machineSize = "Standard_NC16as_T4_v3" // https://docs.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:",
          "mount -o anon nolock \\\\cache.artist.studio\\mnt\\workstation W:"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinArtist/versions/4.0.0"
    machineSize = "Standard_NV32as_v4" // https://docs.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:",
          "mount -o anon nolock \\\\cache.artist.studio\\mnt\\workstation W:"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinArtist/versions/5.0.0"
    machineSize = "Standard_NV36ads_A10_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:",
          "mount -o anon nolock \\\\cache.artist.studio\\mnt\\workstation W:"
        ]
        teradiciLicenseKey = ""
      }
    }
  }
]

# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
