resourceGroupName = "ArtistAnywhere.Scheduler" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    name = "LnxScheduler"
    machine = {
      size = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/0.0.0"
        plan = {
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
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
      name     = "Initialize"
      fileName = "initialize.sh"
      parameters = {
        qubeLicense = { # http://docs.pipelinefx.com/display/QUBE/Metered+Licensing
          userName     = ""
          userPassword = ""
        }
        autoScale = {
          enable                   = false
          fileName                 = "scale.sh"
          scaleSetName             = "LnxFarmC"
          resourceGroupName        = "ArtistAnywhere.Farm"
          jobWaitThresholdSeconds  = 300
          detectionIntervalSeconds = 60
        }
        cycleCloud = { # https://learn.microsoft.com/azure/cyclecloud/overview
          enable             = false
          storageAccountName = "azstudio0"
        }
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name = "" # "WinScheduler"
    machine = {
       size = "Standard_D8s_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
       image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinScheduler/versions/0.0.0"
        plan = {
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
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
      name     = "Initialize"
      fileName = "initialize.ps1"
      parameters = {
        qubeLicense = { # http://docs.pipelinefx.com/display/QUBE/Metered+Licensing
          userName     = ""
          userPassword = ""
        }
        autoScale = {
          enable                   = false
          fileName                 = "scale.ps1"
          scaleSetName             = "WinFarmC"
          resourceGroupName        = "ArtistAnywhere.Farm"
          jobWaitThresholdSeconds  = 300
          detectionIntervalSeconds = 60
        }
        cycleCloud = { # https://learn.microsoft.com/azure/cyclecloud/overview
          enable             = false
          storageAccountName = "azstudio1"
        }
      }
    }
    monitorExtension = {
      enable = false
    }
  }
]

servicePassword = "P@ssword1234"

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

privateDns = {
  aRecordName = "scheduler"
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
