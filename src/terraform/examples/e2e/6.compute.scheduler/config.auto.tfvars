resourceGroupName = "ArtistAnywhere.Scheduler"

############################################################################
# Batch (https://learn.microsoft.com/azure/batch/batch-technical-overview) #
############################################################################

batchAccount = {
  enable = false
  name   = "azrender"
  storageAccount = {
    name              = "azrender0"
    resourceGroupName = "ArtistAnywhere"
  }
  encryption = {
    enable = false
  }
}

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    name = "LnxScheduler"
    image = {
      id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/0.0.0"
      plan = {
        name      = ""
        product   = ""
        publisher = ""
      }
    }
    machineSize = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
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
    name = "" # "WinScheduler"
    image = {
      id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinScheduler/versions/0.0.0"
      plan = {
        name      = ""
        product   = ""
        publisher = ""
      }
    }
    machineSize = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
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
# Optional resource dependency configuration for existing deployments #
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
