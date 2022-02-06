resourceGroupName = "AzureRender.Scheduler"

# Virtual Machines - https://docs.microsoft.com/en-us/azure/virtual-machines/
virtualMachines = [
  {
    name        = "LinuxScheduler"
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/LinuxFarm/versions/10.0.0"
    machineSize = "Standard_D8s_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
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
          "scheduler.media.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0"
        ]
        autoScale = {
          enable            = false
          fileName          = "scale.sh"
          scaleSetName      = "LinuxFarm"
          resourceGroupName = "AzureRender.Farm"
        }
      }
    }
    monitorExtension = {
      enable = true
    }
  },
  {
    name        = ""
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/WindowsScheduler/versions/10.0.0"
    machineSize = "Standard_D8s_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
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
          "mount -o anon \\\\scheduler.media.studio\\DeadlineRepository S:"
        ]
        autoScale = {
          enable            = false
          fileName          = "scale.ps1"
          scaleSetName      = "WindowsFarm"
          resourceGroupName = "AzureRender.Farm"
        }
      }
    }
    monitorExtension = {
      enable = true
    }
  }
]

# Virtual Network - https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview
virtualNetwork = {
  name               = ""
  subnetName         = ""
  resourceGroupName  = ""
  privateDnsZoneName = ""
}
