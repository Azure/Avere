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
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/1.0.0"
        plan = {
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName     = "azadmin"
      userPassword = "P@ssword1234"
      sshPublicKey = "" # "ssh-rsa ..."
      passwordAuth = {
        disable = false
      }
    }
    customExtension = {
      enable   = true
      name     = "Initialize"
      fileName = "initialize.sh"
      parameters = {
        autoScale = {
          enable                   = false
          fileName                 = "scale.sh"
          resourceGroupName        = "ArtistAnywhere.Farm"
          scaleSetName             = "LnxFarmC"
          scaleSetMachineCountMax  = 100
          jobWaitThresholdSeconds  = 300
          workerIdleDeleteSeconds  = 600
          detectionIntervalSeconds = 60
        }
        qubeLicense = { # http://docs.pipelinefx.com/display/QUBE/Metered+Licensing
          userName     = ""
          userPassword = ""
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
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinServer/versions/1.0.0"
        plan = {
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
      }
    }
    adminLogin = {
      userName     = "azadmin"
      userPassword = "P@ssword1234"
      sshPublicKey = "" # "ssh-rsa ..."
      passwordAuth = {
        disable = false
      }
    }
    customExtension = {
      enable   = true
      name     = "Initialize"
      fileName = "initialize.ps1"
      parameters = {
        autoScale = {
          enable                   = false
          fileName                 = "scale.ps1"
          resourceGroupName        = "ArtistAnywhere.Farm"
          scaleSetName             = "WinFarmC"
          scaleSetMachineCountMax  = 100
          jobWaitThresholdSeconds  = 300
          workerIdleDeleteSeconds  = 600
          detectionIntervalSeconds = 60
        }
        qubeLicense = { # http://docs.pipelinefx.com/display/QUBE/Metered+Licensing
          userName     = ""
          userPassword = ""
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
