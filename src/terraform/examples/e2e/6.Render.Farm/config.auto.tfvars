resourceGroupName = "ArtistAnywhere.Farm" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

######################################################################################################
# Virtual Machine Scale Sets (https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) #
######################################################################################################

virtualMachineScaleSets = [
  {
    enable = false
    name   = "LnxFarmC"
    machine = {
      size  = "Standard_HB120rs_v3"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/2.0.0"
        plan = {
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        sizeGB      = 0
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
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
          fileSystemMounts = [
            {
              enable = false # Storage Read
              mount  = "data.artist.studio/default /mnt/data/read wekafs net=udp 0 0"
            },
            {
              enable = false # Storage Read Cache
              mount  = "cache.artist.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
            },
            {
              enable = false # Storage Write
              mount  = "data.artist.studio/default /mnt/data/write wekafs net=udp 0 0"
            },
            {
              enable = false # Storage Write Cache
              mount  = "cache.artist.studio:/mnt/data /mnt/data/write nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
            },
            {
              enable = true # Scheduler Deadline
              mount  = "scheduler.artist.studio:/Deadline /DeadlineServer nfs defaults 0 0"
            }
          ]
          activeDirectory = {
            enable        = false
            domainName    = ""
            serverName    = ""
            orgUnitPath   = ""
            adminUsername = ""
            adminPassword = ""
          }
          terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
            enable       = true
            delayTimeout = "PT5M"
          }
        }
      }
      health = {
        enable      = true
        protocol    = "tcp"
        port        = 111
        requestPath = ""
      }
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "LnxFarmG"
    machine = {
      size  = "Standard_NV36ads_A10_v5"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/2.1.0"
        plan = {
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        sizeGB      = 0
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
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
          fileSystemMounts = [
            {
              enable = false # Storage Read
              mount  = "data.artist.studio/default /mnt/data/read wekafs net=udp 0 0"
            },
            {
              enable = false # Storage Read Cache
              mount  = "cache.artist.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
            },
            {
              enable = false # Storage Write
              mount  = "data.artist.studio/default /mnt/data/write wekafs net=udp 0 0"
            },
            {
              enable = false # Storage Write Cache
              mount  = "cache.artist.studio:/mnt/data /mnt/data/write nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
            },
            {
              enable = true # Scheduler Deadline
              mount  = "scheduler.artist.studio:/Deadline /DeadlineServer nfs defaults 0 0"
            }
          ]
          activeDirectory = {
            enable        = false
            domainName    = ""
            serverName    = ""
            orgUnitPath   = ""
            adminUsername = ""
            adminPassword = ""
          }
          terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
            enable       = true
            delayTimeout = "PT5M"
          }
        }
      }
      health = {
        enable      = true
        protocol    = "tcp"
        port        = 111
        requestPath = ""
      }
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "WinFarmC"
    machine = {
      size  = "Standard_HB120rs_v3"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinFarm/versions/2.0.0"
        plan = {
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        sizeGB      = 0
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
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
          activeDirectory = {
            enable        = true
            domainName    = "artist.studio"
            serverName    = "WinScheduler"
            orgUnitPath   = ""
            adminUsername = "azadmin"
            adminPassword = "P@ssword1234"
          }
          terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
            enable       = true
            delayTimeout = "PT5M"
          }
        }
      }
      health = {
        enable      = true
        protocol    = "tcp"
        port        = 445
        requestPath = ""
      }
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "WinFarmG"
    machine = {
      size  = "Standard_NV36ads_A10_v5"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinFarm/versions/2.1.0"
        plan = {
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        sizeGB      = 0
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
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
          activeDirectory = {
            enable        = true
            domainName    = "artist.studio"
            serverName    = "WinScheduler"
            orgUnitPath   = ""
            adminUsername = "azadmin"
            adminPassword = "P@ssword1234"
          }
          terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
            enable       = true
            delayTimeout = "PT5M"
          }
        }
      }
      health = {
        enable      = true
        protocol    = "tcp"
        port        = 445
        requestPath = ""
      }
      monitor = {
        enable = false
      }
    }
  }
]

############################################################################
# Batch (https://learn.microsoft.com/azure/batch/batch-technical-overview) #
############################################################################

batch = {
  account = {
    name = "" # Set to a unique name to deploy Batch instead of VMSS
  }
  pools = [
    {
      name        = "LnxFarmC"
      displayName = "Linux Render Farm (CPU)"
      node = {
        image = {
          id      = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/2.0.0"
          agentId = "batch.node.el 9"
        }
        machine = {
          size  = "Standard_HB120rs_v3" # https://learn.microsoft.com/azure/batch/batch-pool-vm-sizes
          count = 2
        }
        osDisk = {
          ephemeral = {
            enable = true # https://learn.microsoft.com/azure/batch/create-pool-ephemeral-os-disk
          }
        }
        deallocationMode   = "Terminate"
        maxConcurrentTasks = 1
      }
      spot = {
        enable = true # https://learn.microsoft.com/azure/batch/batch-spot-vms
      }
      fillMode = {
        nodePack = false
      }
    }
  ]
}

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}

storageAccount = {
  name               = ""
  resourceGroupName  = ""
}
