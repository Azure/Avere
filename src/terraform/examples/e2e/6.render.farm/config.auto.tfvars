resourceGroupName = "ArtistAnywhere.Farm" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

######################################################################################################
# Virtual Machine Scale Sets (https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) #
######################################################################################################

virtualMachineScaleSets = [
  {
    name = "LnxFarmC"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 2
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
      enableAcceleratedNetworking = true
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
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache file system mount (fsMount)
          enableWrite = false # Set to true to enable storageWriteCache file system mount (fsMount)
        }
        fsMount = {
          storageRead       = "azstudio1.blob.core.windows.net:/azstudio1/data /mnt/data/read nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
          storageReadCache  = "cache.content.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          storageWrite      = "azstudio1.blob.core.windows.net:/azstudio1/data /mnt/data/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
          storageWriteCache = "cache.content.studio:/mnt/data /mnt/data/write nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          schedulerDeadline = "scheduler.content.studio:/Deadline /Deadline nfs defaults 0 0"
        }
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    terminateNotification = {   # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable                   = true
      timeoutDelay             = "PT5M"
      detectionIntervalSeconds = 5
    }
  },
  {
    name = "" # "LnxFarmG"
    machine = {
      size  = "Standard_NV36ads_A10_v5"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/1.1.0"
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
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
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
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache file system mount (fsMount)
          enableWrite = false # Set to true to enable storageWriteCache file system mount (fsMount)
        }
        fsMount = {
          storageRead       = "azstudio1.blob.core.windows.net:/azstudio1/data /mnt/data/read nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
          storageReadCache  = "cache.content.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          storageWrite      = "azstudio1.blob.core.windows.net:/azstudio1/data /mnt/data/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
          storageWriteCache = "cache.content.studio:/mnt/data /mnt/data/write nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          schedulerDeadline = "scheduler.content.studio:/Deadline /Deadline nfs defaults 0 0"
        }
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    terminateNotification = {   # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable                   = true
      timeoutDelay             = "PT5M"
      detectionIntervalSeconds = 5
    }
  },
  {
    name = "" # "WinFarmC"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinFarm/versions/1.0.0"
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
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
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
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache file system mount (fsMount)
          enableWrite = false # Set to true to enable storageWriteCache file system mount (fsMount)
        }
        fsMount = {
          storageRead       = "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\data R:"
          storageReadCache  = "mount -o anon nolock \\\\cache.content.studio\\mnt\\data R:"
          storageWrite      = "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\data W:"
          storageWriteCache = "mount -o anon nolock \\\\cache.content.studio\\mnt\\data W:"
          schedulerDeadline = "mount -o anon \\\\scheduler.content.studio\\Deadline X:"
        }
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    terminateNotification = {   # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable                   = true
      timeoutDelay             = "PT5M"
      detectionIntervalSeconds = 5
    }
  },
  {
    name = "" # "WinFarmG"
    machine = {
      size  = "Standard_NV36ads_A10_v5"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinFarm/versions/1.1.0"
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
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
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
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache file system mount (fsMount)
          enableWrite = false # Set to true to enable storageWriteCache file system mount (fsMount)
        }
        fsMount = {
          storageRead       = "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\data R:"
          storageReadCache  = "mount -o anon nolock \\\\cache.content.studio\\mnt\\data R:"
          storageWrite      = "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\data W:"
          storageWriteCache = "mount -o anon nolock \\\\cache.content.studio\\mnt\\data W:"
          schedulerDeadline = "mount -o anon \\\\scheduler.content.studio\\Deadline X:"
        }
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    terminateNotification = {   # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable                   = true
      timeoutDelay             = "PT5M"
      detectionIntervalSeconds = 5
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
