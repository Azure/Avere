resourceGroupName = "ArtistAnywhere.Scheduler"

# Virtual Machines (https://docs.microsoft.com/azure/virtual-machines)
virtualMachines = [
  {
    name        = "LnxScheduler"
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/0.0.0"
    machineSize = "Standard_D8as_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
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
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0"
        ]
        autoScale = {
          enable                   = false
          fileName                 = "scale.sh"
          scaleSetName             = "LnxFarm"
          resourceGroupName        = "ArtistAnywhere.Farm"
          detectionIntervalSeconds = 60
          jobWaitThresholdSeconds  = 300
          workerIdleDeleteSeconds  = 3600
        }
        cycleCloud = { // https://docs.microsoft.com/azure/cyclecloud/overview
          enable = false
          storageAccount = {
            name       = ""
            type       = "StorageV2"
            tier       = "Standard"
            redundancy = "LRS"
          }
        }
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name        = "" // "WinScheduler"
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinScheduler/versions/0.0.0"
    machineSize = "Standard_D8as_v5" // https://docs.microsoft.com/azure/virtual-machines/sizes
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
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:"
        ]
        autoScale = {
          enable                   = false
          fileName                 = "scale.ps1"
          scaleSetName             = "WinFarm"
          resourceGroupName        = "ArtistAnywhere.Farm"
          detectionIntervalSeconds = 60
          jobWaitThresholdSeconds  = 300
          workerIdleDeleteSeconds  = 3600
        }
        cycleCloud = { // https://docs.microsoft.com/azure/cyclecloud/overview
          enable = false
          storageAccount = {
            name       = ""
            type       = "StorageV2"
            tier       = "Standard"
            redundancy = "LRS"
          }
        }
      }
    }
    monitorExtension = {
      enable = false
    }
  }
]

# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name               = ""
  subnetName         = ""
  resourceGroupName  = ""
  privateDnsZoneName = ""
}
