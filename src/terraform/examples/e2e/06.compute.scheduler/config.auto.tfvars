resourceGroupName = "ArtistAnywhere.Scheduler"

# Virtual Machines (https://docs.microsoft.com/en-us/azure/virtual-machines)
virtualMachines = [
  {
    name        = "LnxScheduler"
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/10.0.0"
    machineSize = "Standard_D16s_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
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
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0"
        ]
        autoScale = {
          enable                   = false
          fileName                 = "scale.sh"
          scaleSetName             = "LnxFarm1"
          resourceGroupName        = "ArtistAnywhere.Farm"
          detectionIntervalSeconds = 60
          workerIdleSecondsDelete  = 3600
        }
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name        = "" // "WinScheduler"
    imageId     = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinScheduler/versions/10.0.0"
    machineSize = "Standard_D16s_v5" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
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
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:"
        ]
        autoScale = {
          enable                   = false
          fileName                 = "scale.ps1"
          scaleSetName             = "WinFarm1"
          resourceGroupName        = "ArtistAnywhere.Farm"
          detectionIntervalSeconds = 60
          workerIdleSecondsDelete  = 3600
        }
      }
    }
    monitorExtension = {
      enable = false
    }
  }
]

# Virtual Network (https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name               = ""
  subnetName         = ""
  resourceGroupName  = ""
  privateDnsZoneName = ""
}
