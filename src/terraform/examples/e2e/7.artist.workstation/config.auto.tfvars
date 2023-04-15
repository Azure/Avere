resourceGroupName = "ArtistAnywhere.Workstation" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    name = "LnxArtist"
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
      enableAcceleratedNetworking = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
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
        teradiciLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name = "WinArtist"
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
      enableAcceleratedNetworking = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
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
