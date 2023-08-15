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
      staticIpAddress    = ""
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
        sizeGB      = 0
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
      fileName = "initialize.sh"
      parameters = {
        activeDirectory = {
          domainName    = ""
          adminPassword = ""
        }
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
      staticIpAddress    = "10.1.127.0"
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
        sizeGB      = 0
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
      fileName = "initialize.ps1"
      parameters = {
        activeDirectory = {
          domainName    = "artist.studio"
          adminPassword = "P@ssword1234"
        }
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
      }
    }
    monitorExtension = {
      enable = false
    }
  }
]

serviceAccount = {
  name     = "aaaService"
  password = "P@ssword1234"
}

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
