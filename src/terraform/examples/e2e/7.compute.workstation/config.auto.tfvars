resourceGroupName = "AzureRender.Workstation"

# Virtual Machines - https://docs.microsoft.com/en-us/azure/virtual-machines/
virtualMachines = [
  {
    name        = "LinuxArtist3"
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/LinuxWorkstation/versions/3.0.0"
    machineSize = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type        = "Linux"
      licenseType = ""
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    adminLogin = {
      username     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "cache.media.studio:/mnt/workstation /mnt/show nfs hard,proto=tcp,mountproto=tcp,retry=30 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = "LinuxArtist4"
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/LinuxWorkstation/versions/4.0.0"
    machineSize = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    adminLogin = {
      username     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "cache.media.studio:/mnt/workstation /mnt/show nfs hard,proto=tcp,mountproto=tcp,retry=30 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/WindowsWorkstation/versions/3.0.0"
    machineSize = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    adminLogin = {
      username     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon cache.media.studio:/mnt/workstation W:"
        ]
        teradiciLicenseKey = ""
      }
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/WindowsWorkstation/versions/4.0.0"
    machineSize = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
      }
    }
    adminLogin = {
      username     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon cache.media.studio:/mnt/workstation W:"
        ]
        teradiciLicenseKey = ""
      }
    }
  }
]

# Virtual Network - https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview
virtualNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
