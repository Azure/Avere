resourceGroupName = "ArtistAnywhere.Scheduler" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    name        = "LnxScheduler"
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/Linux/versions/0.0.0"
    machineSize = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
    network = {
      enableAcceleratedNetworking = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = ""
      userPassword        = ""
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.sh"
      parameters = {
        fileSystemMountsStorage = [
        ]
        fileSystemMountsStorageCache = [
        ]
        fileSystemMountsRoyalRender = [
        ]
        fileSystemMountsDeadline = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0"
        ]
        autoScale = {
          enable                   = false
          fileName                 = "scale.auto.sh"
          scaleSetName             = "LnxFarm"
          resourceGroupName        = "ArtistAnywhere.Farm"
          detectionIntervalSeconds = 60
          jobWaitThresholdSeconds  = 300
          workerIdleDeleteSeconds  = 3600
        }
        cycleCloud = { # https://learn.microsoft.com/azure/cyclecloud/overview
          enable             = false
          storageAccountName = "azrender0"
        }
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name        = "" # "WinScheduler"
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/WinScheduler/versions/0.0.0"
    machineSize = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
    network = {
      enableAcceleratedNetworking = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = ""
      userPassword        = ""
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMountsStorage = [
        ]
        fileSystemMountsStorageCache = [
        ]
        fileSystemMountsRoyalRender = [
        ]
        fileSystemMountsDeadline = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:"
        ]
        autoScale = {
          enable                   = false
          fileName                 = "scale.auto.ps1"
          scaleSetName             = "WinFarm"
          resourceGroupName        = "ArtistAnywhere.Farm"
          detectionIntervalSeconds = 60
          jobWaitThresholdSeconds  = 300
          workerIdleDeleteSeconds  = 3600
        }
        cycleCloud = { # https://learn.microsoft.com/azure/cyclecloud/overview
          enable             = false
          storageAccountName = "azrender1"
        }
      }
    }
    monitorExtension = {
      enable = false
    }
  }
]

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name               = ""
  subnetName         = ""
  resourceGroupName  = ""
  privateDnsZoneName = ""
}

computeGallery = { # Only applies if customExtension.cycleCloud.enable = true
  name                  = ""
  resourceGroupName     = ""
  imageVersionIdDefault = ""
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

monitorWorkspace = {
  name              = ""
  resourceGroupName = ""
}
