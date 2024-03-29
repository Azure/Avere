resourceGroupName = "ArtistAnywhere.Workstation" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

activeDirectory = {
  enable           = true
  domainName       = "artist.studio"
  domainServerName = "WinScheduler"
  orgUnitPath      = ""
  adminUsername    = ""
  adminPassword    = ""
}

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    enable = false
    name   = "LnxArtistNVIDIA"
    machine = {
      size = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/3.0.0"
        plan = {
          enable    = false
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
        sizeGB      = 0
      }
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
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
          fileSystems = [
            {
              enable = false # File Storage
              mounts = [
                "URI_TO_AZURE_STORAGE_ACCOUNT:/azstudio1/content /mnt/content aznfs default,sec=sys,proto=tcp,vers=3,nolock 0 0"
              ]
            },
            {
              enable = false # File Cache
              mounts = [
                "cache.artist.studio:/content /mnt/content nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
              ]
            },
            {
              enable = true # Job Scheduler
              mounts = [
                "scheduler.artist.studio:/deadline /mnt/deadline nfs defaults 0 0"
              ]
            }
          ]
          pcoipLicenseKey = ""
        }
      }
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "LnxArtistAMD"
    machine = {
      size = "Standard_NG32ads_V620_v1" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/3.1.0"
        plan = {
          enable    = false
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
        sizeGB      = 0
      }
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
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
          fileSystems = [
            {
              enable = false # File Storage
              mounts = [
                "URI_TO_AZURE_STORAGE_ACCOUNT:/azstudio1/content /mnt/content aznfs default,sec=sys,proto=tcp,vers=3,nolock 0 0"
              ]
            },
            {
              enable = false # File Cache
              mounts = [
                "cache.artist.studio:/content /mnt/content nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
              ]
            },
            {
              enable = true # Job Scheduler
              mounts = [
                "scheduler.artist.studio:/deadline /mnt/deadline nfs defaults 0 0"
              ]
            }
          ]
          pcoipLicenseKey = ""
        }
      }
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "WinArtistNVIDIA"
    machine = {
      size = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinArtist/versions/3.0.0"
        plan = {
          enable    = false
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
        sizeGB      = 0
      }
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
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
          fileSystems = [
            {
              enable = false # File Storage
              mounts = [
                "mount -o anon nolock \\\\URI_TO_AZURE_STORAGE_ACCOUNT\\azstudio1\\content X:"
              ]
            },
            {
              enable = false # File Cache
              mounts = [
                "mount -o anon nolock \\\\cache.artist.studio\\content H:"
              ]
            },
            {
              enable = true # Job Scheduler
              mounts = [
                "mount -o anon \\\\scheduler.artist.studio\\deadline S:"
              ]
            }
          ]
          pcoipLicenseKey = ""
        }
      }
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "WinArtistAMD"
    machine = {
      size = "Standard_NG32ads_V620_v1" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinArtist/versions/3.1.0"
        plan = {
          enable    = false
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
        sizeGB      = 0
      }
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
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
          fileSystems = [
            {
              enable = false # File Storage
              mounts = [
                "mount -o anon nolock \\\\URI_TO_AZURE_STORAGE_ACCOUNT\\azstudio1\\content X:"
              ]
            },
            {
              enable = false # File Cache
              mounts = [
                "mount -o anon nolock \\\\cache.artist.studio\\content H:"
              ]
            },
            {
              enable = true # Job Scheduler
              mounts = [
                "mount -o anon \\\\scheduler.artist.studio\\deadline S:"
              ]
            }
          ]
          pcoipLicenseKey = ""
        }
      }
      monitor = {
        enable = false
      }
    }
  }
]

###############################################################################################
# Traffic Manager (https://learn.microsoft.comazure/traffic-manager/traffic-manager-overview) #
###############################################################################################

trafficManager = {
  enable = false
  profile = {
    name              = ""
    routingMethod     = "Performance"
    enableTrafficView = true
  }
  dns = {
    name = "artistanywhere"
    ttl  = 100
  }
}

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

existingNetwork = {
  enable            = false
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
