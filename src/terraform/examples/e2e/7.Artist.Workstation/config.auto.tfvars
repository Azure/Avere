resourceGroupName = "ArtistAnywhere.Workstation" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

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
    activeDirectory = {
      enable           = false
      domainName       = ""
      domainServerName = ""
      orgUnitPath      = ""
      adminUsername    = ""
      adminPassword    = ""
    }
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.sh"
        parameters = {
          fileSystemMounts = [
            {
              enable = false # File Storage Read
              mount  = "azstudio1.blob.core.windows.net/azstudio1/content /mnt/content nfs sec=sys,vers=4,minorversion=1 0 0"
            },
            {
              enable = false # File Cache Read
              mount  = "cache.artist.studio/mnt/content /mnt/content nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
            },
            {
              enable = false # File Storage Write
              mount  = "azstudio1.blob.core.windows.net/azstudio1/content /mnt/content nfs sec=sys,vers=4,minorversion=1 0 0"
            },
            {
              enable = false # File Cache Write
              mount  = "cache.artist.studio/mnt/content /mnt/content nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
            },
            {
              enable = true # Job Scheduler
              mount  = "scheduler.artist.studio/Deadline /DeadlineServer nfs defaults 0 0"
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
    activeDirectory = {
      enable           = false
      domainName       = ""
      domainServerName = ""
      orgUnitPath      = ""
      adminUsername    = ""
      adminPassword    = ""
    }
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.sh"
        parameters = {
          fileSystemMounts = [
            {
              enable = false # File Storage Read
              mount  = "azstudio1.blob.core.windows.net/azstudio1/content /mnt/content nfs sec=sys,vers=4,minorversion=1 0 0"
            },
            {
              enable = false # File Cache Read
              mount  = "cache.artist.studio/mnt/content /mnt/content nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
            },
            {
              enable = false # File Storage Write
              mount  = "azstudio1.blob.core.windows.net/azstudio1/content /mnt/content nfs sec=sys,vers=4,minorversion=1 0 0"
            },
            {
              enable = false # File Cache Write
              mount  = "cache.artist.studio/mnt/content /mnt/content nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
            },
            {
              enable = true # Job Scheduler
              mount  = "scheduler.artist.studio/Deadline /DeadlineServer nfs defaults 0 0"
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
    activeDirectory = {
      enable           = false
      domainName       = "artist.studio"
      domainServerName = "WinScheduler"
      orgUnitPath      = ""
      adminUsername    = ""
      adminPassword    = ""
    }
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.ps1"
        parameters = {
          fileSystemMounts = [
            {
              enable = false # File Storage Read
              mount  = "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\content R:"
            },
            {
              enable = false # File Cache Read
              mount  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\content R:"
            },
            {
              enable = false # File Storage Write
              mount  = "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\content W:"
            },
            {
              enable = false # File Cache Write
              mount  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\content W:"
            },
            {
              enable = true # Job Scheduler
              mount  = "mount -o anon \\\\scheduler.artist.studio\\Deadline S:"
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
    activeDirectory = {
      enable           = false
      domainName       = "artist.studio"
      domainServerName = "WinScheduler"
      orgUnitPath      = ""
      adminUsername    = ""
      adminPassword    = ""
    }
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.ps1"
        parameters = {
          fileSystemMounts = [
            {
              enable = false # File Storage Read
              mount  = "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\content R:"
            },
            {
              enable = false # File Cache Read
              mount  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\content R:"
            },
            {
              enable = false # File Storage Write
              mount  = "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\content W:"
            },
            {
              enable = false # File Cache Write
              mount  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\content W:"
            },
            {
              enable = true # Job Scheduler
              mount  = "mount -o anon \\\\scheduler.artist.studio\\Deadline S:"
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

computeNetwork = {
  enable            = false
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
