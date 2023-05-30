resourceGroupName = "ArtistAnywhere.Workstation" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    name = "" # "LnxArtistCPU"
    machine = {
      size = "Standard_D32ads_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
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
      name     = "Initialize"
      fileName = "initialize.sh"
      parameters = {
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache within fileSystemMount
          enableWrite = false # Set to true to enable storageWriteCache within fileSystemMount
        }
        fileSystemMount = {
          enable            = false
          storageRead       = "data.artist.studio/default /mnt/data wekafs net=udp 0 0"
          storageReadCache  = "cache.artist.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          storageWrite      = "data.artist.studio/default /mnt/data wekafs net=udp 0 0"
          storageWriteCache = "cache.artist.studio:/mnt/data /mnt/data/write nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          schedulerDeadline = "scheduler.artist.studio:/Deadline /DeadlineServer nfs defaults 0 0"
        }
        teradiciLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name = "LnxArtistGPU"
    machine = {
      size = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/3.1.0"
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
      name     = "Initialize"
      fileName = "initialize.sh"
      parameters = {
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache within fileSystemMount
          enableWrite = false # Set to true to enable storageWriteCache within fileSystemMount
        }
        fileSystemMount = {
          enable            = false
          storageRead       = "data.artist.studio/default /mnt/data wekafs net=udp 0 0"
          storageReadCache  = "cache.artist.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          storageWrite      = "data.artist.studio/default /mnt/data wekafs net=udp 0 0"
          storageWriteCache = "cache.artist.studio:/mnt/data /mnt/data/write nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
          schedulerDeadline = "scheduler.artist.studio:/Deadline /DeadlineServer nfs defaults 0 0"
        }
        teradiciLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name = "" # "WinArtistCPU"
    machine = {
      size = "Standard_D32ads_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
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
      name     = "Initialize"
      fileName = "initialize.ps1"
      parameters = {
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache within fileSystemMount
          enableWrite = false # Set to true to enable storageWriteCache within fileSystemMount
        }
        fileSystemMount = {
          enable            = false
          storageRead       = "net use R: \\\\data.artist.studio\\default /persistent:yes"
          storageReadCache  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data R:"
          storageWrite      = "net use W: \\\\data.artist.studio\\default /persistent:yes"
          storageWriteCache = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data W:"
          schedulerDeadline = "net use S: \\\\scheduler.artist.studio\\Deadline /persistent:yes"
        }
        teradiciLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name = "WinArtistGPU"
    machine = {
      size = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinArtist/versions/3.1.0"
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
      name     = "Initialize"
      fileName = "initialize.ps1"
      parameters = {
        storageCache = {
          enableRead  = false # Set to true to enable storageReadCache within fileSystemMount
          enableWrite = false # Set to true to enable storageWriteCache within fileSystemMount
        }
        fileSystemMount = {
          enable            = false
          storageRead       = "net use R: \\\\data.artist.studio\\default /persistent:yes"
          storageReadCache  = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data R:"
          storageWrite      = "net use W: \\\\data.artist.studio\\default /persistent:yes"
          storageWriteCache = "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data W:"
          schedulerDeadline = "net use S: \\\\scheduler.artist.studio\\Deadline /persistent:yes"
        }
        teradiciLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
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
