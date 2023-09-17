resourceGroupName = "ArtistAnywhere.Workstation" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    name = "LnxArtistNVIDIA"
    machine = {
      size = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/3.0.0"
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
          serverName    = ""
          adminUsername = ""
          adminPassword = ""
        }
        fileSystemMounts = [
          {
            enable = false # Storage Read
            mount  = "data.artist.studio/default /mnt/data wekafs net=udp 0 0"
          },
          {
            enable = false # Storage Read Cache
            mount  = "cache.artist.studio:/mnt/data /mnt/data nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          },
          {
            enable = false # Storage Write
            mount  = "data.artist.studio/default /mnt/data wekafs net=udp 0 0"
          },
          {
            enable = false # Storage Write Cache
            mount  = "cache.artist.studio:/mnt/data /mnt/data nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          },
          {
            enable = true # Scheduler Deadline
            mount  = "scheduler.artist.studio:/Deadline /DeadlineServer nfs defaults 0 0"
          }
        ]
        pcoipLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  # {
  #   name = "LnxArtistAMD"
  #   machine = {
  #     size = "Standard_NG32ads_V620_v1" # https://learn.microsoft.com/azure/virtual-machines/sizes
  #     image = {
  #       id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/3.1.0"
  #       plan = {
  #         publisher = ""
  #         product   = ""
  #         name      = ""
  #       }
  #     }
  #   }
  #   network = {
  #     enableAcceleration = true
  #   }
  #   operatingSystem = {
  #     type = "Linux"
  #     disk = {
  #       storageType = "Premium_LRS"
  #       cachingType = "ReadWrite"
  #       sizeGB      = 0
  #     }
  #   }
  #   adminLogin = {
  #     userName     = "azadmin"
  #     userPassword = "P@ssword1234"
  #     sshPublicKey = "" # "ssh-rsa ..."
  #     passwordAuth = {
  #       disable = false
  #     }
  #   }
  #   customExtension = {
  #     enable   = true
  #     fileName = "initialize.sh"
  #     parameters = {
  #       activeDirectory = {
  #         domainName    = ""
  #         serverName    = ""
  #         adminUsername = ""
  #         adminPassword = ""
  #       }
  #       fileSystemMounts = [
  #         {
  #           enable = false # Storage Read
  #           mount  = "data.artist.studio/default /mnt/data wekafs net=udp 0 0"
  #         },
  #         {
  #           enable = false # Storage Read Cache
  #           mount  = "cache.artist.studio:/mnt/data /mnt/data nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
  #         },
  #         {
  #           enable = false # Storage Write
  #           mount  = "data.artist.studio/default /mnt/data wekafs net=udp 0 0"
  #         },
  #         {
  #           enable = false # Storage Write Cache
  #           mount  = "cache.artist.studio:/mnt/data /mnt/data nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
  #         },
  #         {
  #           enable = true # Scheduler Deadline
  #           mount  = "scheduler.artist.studio:/Deadline /DeadlineServer nfs defaults 0 0"
  #         }
  #       ]
  #       pcoipLicenseKey = ""
  #     }
  #   }
  #   monitorExtension = {
  #     enable = false
  #   }
  # },
  {
    name = "WinArtistNVIDIA"
    machine = {
      size = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinArtist/versions/3.0.0"
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
          domainName    = "" # "artist.studio"
          serverName    = "WinScheduler"
          adminUsername = "azadmin"
          adminPassword = "P@ssword1234"
        }
        fileSystemMounts = [
          {
            enable = false # Storage Read
            mount  = "mount -o anon \\\\data.artist.studio\\default R:"
          },
          {
            enable = false # Storage Read Cache
            mount  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data R:"
          },
          {
            enable = false # Storage Write
            mount  = "mount -o anon \\\\data.artist.studio\\default W:"
          },
          {
            enable = false # Storage Write Cache
            mount  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data W:"
          },
          {
            enable = true # Scheduler Deadline
            mount  = "mount -o anon \\\\scheduler.artist.studio\\Deadline S:"
          }
        ]
        pcoipLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  # {
  #   name = "WinArtistAMD"
  #   machine = {
  #     size = "Standard_NG32ads_V620_v1" # https://learn.microsoft.com/azure/virtual-machines/sizes
  #     image = {
  #       id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinArtist/versions/3.1.0"
  #       plan = {
  #         publisher = ""
  #         product   = ""
  #         name      = ""
  #       }
  #     }
  #   }
  #   network = {
  #     enableAcceleration = true
  #   }
  #   operatingSystem = {
  #     type = "Windows"
  #     disk = {
  #       storageType = "Premium_LRS"
  #       cachingType = "ReadWrite"
  #       sizeGB      = 0
  #     }
  #   }
  #   adminLogin = {
  #     userName     = "azadmin"
  #     userPassword = "P@ssword1234"
  #     sshPublicKey = "" # "ssh-rsa ..."
  #     passwordAuth = {
  #       disable = false
  #     }
  #   }
  #   customExtension = {
  #     enable   = true
  #     fileName = "initialize.ps1"
  #     parameters = {
  #       activeDirectory = {
  #         domainName    = "" # "artist.studio"
  #         serverName    = "WinScheduler"
  #         adminUsername = "azadmin"
  #         adminPassword = "P@ssword1234"
  #       }
  #       fileSystemMounts = [
  #         {
  #           enable = false # Storage Read
  #           mount  = "mount -o anon \\\\data.artist.studio\\default R:"
  #         },
  #         {
  #           enable = false # Storage Read Cache
  #           mount  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data R:"
  #         },
  #         {
  #           enable = false # Storage Write
  #           mount  = "mount -o anon \\\\data.artist.studio\\default W:"
  #         },
  #         {
  #           enable = false # Storage Write Cache
  #           mount  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data W:"
  #         },
  #         {
  #           enable = true # Scheduler Deadline
  #           mount  = "mount -o anon \\\\scheduler.artist.studio\\Deadline S:"
  #         }
  #       ]
  #       pcoipLicenseKey = ""
  #     }
  #   }
  #   monitorExtension = {
  #     enable = false
  #   }
  # }
]

###############################################################################################
# Traffic Manager (https://learn.microsoft.comazure/traffic-manager/traffic-manager-overview) #
###############################################################################################

trafficManager = {
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
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
