resourceGroupName = "ArtistAnywhere.Farm" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

######################################################################################################
# Virtual Machine Scale Sets (https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) #
######################################################################################################

virtualMachineScaleSets = [
  {
    name = "LnxFarmC"
    machine = {
      size  = "Standard_D48ads_v5"
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
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
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
    customExtension = {
      enable   = true
      name     = "Initialize"
      fileName = "initialize.sh"
      parameters = {
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache within fileSystemMount
          enableWrite = false # Set to true to enable storageWriteCache within fileSystemMount
        }
        fileSystemMount = {
          enable            = false
          storageRead       = "data.content.studio/default /mnt/data wekafs net=udp 0 0"
          storageReadCache  = "cache.content.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          storageWrite      = "data.content.studio/default /mnt/data wekafs net=udp 0 0"
          storageWriteCache = "cache.content.studio:/mnt/data /mnt/data/write nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          schedulerDeadline = "scheduler.content.studio:/Deadline /DeadlineServer nfs defaults 0 0"
        }
        terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
          enable       = true
          delayTimeout = "PT5M"
        }
      }
    }
    healthExtension = {
      enable      = true
      protocol    = "tcp"
      port        = 111
      requestPath = ""
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
  },
  {
    name = "" # "LnxFarmG"
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
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
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
    customExtension = {
      enable   = true
      name     = "Initialize"
      fileName = "initialize.sh"
      parameters = {
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache within fileSystemMount
          enableWrite = false # Set to true to enable storageWriteCache within fileSystemMount
        }
        fileSystemMount = {
          enable            = false
          storageRead       = "data.content.studio/default /mnt/data wekafs net=udp 0 0"
          storageReadCache  = "cache.content.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          storageWrite      = "data.content.studio/default /mnt/data wekafs net=udp 0 0"
          storageWriteCache = "cache.content.studio:/mnt/data /mnt/data/write nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          schedulerDeadline = "scheduler.content.studio:/Deadline /DeadlineServer nfs defaults 0 0"
        }
        terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
          enable       = true
          delayTimeout = "PT5M"
        }
      }
    }
    healthExtension = {
      enable      = true
      protocol    = "tcp"
      port        = 111
      requestPath = ""
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
  },
  {
    name = "" # "WinFarmC"
    machine = {
      size  = "Standard_D48ads_v5"
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
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
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
    customExtension = {
      enable   = true
      name     = "Initialize"
      fileName = "initialize.ps1"
      parameters = {
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache within fileSystemMount
          enableWrite = false # Set to true to enable storageWriteCache within fileSystemMount
        }
        fileSystemMount = {
          enable            = false
          storageRead       = "net use R: \\\\data.content.studio\\default /persistent:yes"
          storageReadCache  = "mount -o anon nolock \\\\cache.content.studio\\mnt\\data R:"
          storageWrite      = "net use W: \\\\data.content.studio\\default /persistent:yes"
          storageWriteCache = "mount -o anon nolock \\\\cache.content.studio\\mnt\\data W:"
          schedulerDeadline = "net use S: \\\\scheduler.content.studio\\Deadline /persistent:yes"
        }
        terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
          enable       = true
          delayTimeout = "PT5M"
        }
      }
    }
    healthExtension = {
      enable      = true
      protocol    = "tcp"
      port        = 445
      requestPath = ""
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
  },
  {
    name = "" # "WinFarmG"
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
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
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
    customExtension = {
      enable   = true
      name     = "Initialize"
      fileName = "initialize.ps1"
      parameters = {
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache within fileSystemMount
          enableWrite = false # Set to true to enable storageWriteCache within fileSystemMount
        }
        fileSystemMount = {
          enable            = false
          storageRead       = "net use R: \\\\data.content.studio\\default /persistent:yes"
          storageReadCache  = "mount -o anon nolock \\\\cache.content.studio\\mnt\\data R:"
          storageWrite      = "net use W: \\\\data.content.studio\\default /persistent:yes"
          storageWriteCache = "mount -o anon nolock \\\\cache.content.studio\\mnt\\data W:"
          schedulerDeadline = "net use S: \\\\scheduler.content.studio\\Deadline /persistent:yes"
        }
        terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
          enable       = true
          delayTimeout = "PT5M"
        }
      }
    }
    healthExtension = {
      enable      = true
      protocol    = "tcp"
      port        = 445
      requestPath = ""
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
  }
]

servicePassword = "P@ssword1234"

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
