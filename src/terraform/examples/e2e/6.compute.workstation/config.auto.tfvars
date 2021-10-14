resourceGroupName = "AzureRender.Workstation"

# Virtual Machines - https://docs.microsoft.com/en-us/azure/virtual-machines/
virtualMachines = [
  {
    name    = ""
    imageId = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/LinuxWorkstationV3/versions/1.0.0"
    sizeSku = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    osType  = "Linux"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadWrite"
    }
    adminLogin = {
      username     = "azureadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    script = {
      file = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "cache.media.studio.:/mnt/workstation /mnt/show nfs hard,proto=tcp,mountproto=tcp,retry=30 0 0"
        ]
      }
    }
  },
  {
    name    = ""
    imageId = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/LinuxWorkstationV4/versions/1.0.0"
    sizeSku = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    osType  = "Linux"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadWrite"
    }
    adminLogin = {
      username     = "azureadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    script = {
      file = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "cache.media.studio.:/mnt/workstation /mnt/show nfs hard,proto=tcp,mountproto=tcp,retry=30 0 0"
        ]
      }
    }
  },
  {
    name     = ""
    imageId  = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/WindowsWorkstationV3/versions/1.0.0"
    sizeSku  = "Standard_NV48s_v3" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    osType   = "Windows"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadWrite"
    }
    adminLogin = {
      username     = "azureadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    script = {
      file = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
        ]
      }
    }
  },
  {
    name     = ""
    imageId  = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/WindowsWorkstationV4/versions/1.0.0"
    sizeSku  = "Standard_NV32as_v4" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    osType   = "Windows"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadWrite"
    }
    adminLogin = {
      username     = "azureadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    script = {
      file = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
        ]
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
