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
      userName            = "azadmin"
      userPassword        = "P@ssword1234"
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.sh"
      parameters = {
        qubeLicense = { # http://docs.pipelinefx.com/display/QUBE/Metered+Licensing
          userName     = ""
          userPassword = ""
        }
        autoScale = {
          enable                   = false
          fileName                 = "scale.auto.sh"
          scaleSetName             = "LnxFarmG"
          resourceGroupName        = "ArtistAnywhere.Farm"
          jobWaitThresholdSeconds  = 300
          detectionIntervalSeconds = 60
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
      userName            = "azadmin"
      userPassword        = "P@ssword1234"
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.ps1"
      parameters = {
        qubeLicense = { # http://docs.pipelinefx.com/display/QUBE/Metered+Licensing
          userName     = ""
          userPassword = ""
        }
        autoScale = {
          enable                   = false
          fileName                 = "scale.auto.ps1"
          scaleSetName             = "WinFarmG"
          resourceGroupName        = "ArtistAnywhere.Farm"
          jobWaitThresholdSeconds  = 300
          detectionIntervalSeconds = 60
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

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

privateDns = {
  aRecordName = "render"
  ttlSeconds  = 300
}

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
