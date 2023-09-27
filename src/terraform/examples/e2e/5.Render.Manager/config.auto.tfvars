resourceGroupName = "ArtistAnywhere.Scheduler" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    enable = false
    name   = "LnxScheduler"
    machine = {
      size = "Standard_D8as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/1.0.0"
        plan = {
          enable    = false
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
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.sh"
        parameters = {
          activeDirectory = {
            enable        = false
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
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "WinScheduler"
    machine = {
       size = "Standard_D8as_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
       image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinServer/versions/1.0.0"
        plan = {
          enable    = false
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
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.ps1"
        parameters = {
          activeDirectory = {
            enable        = true
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
      monitor = {
        enable = false
      }
    }
  }
]

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
