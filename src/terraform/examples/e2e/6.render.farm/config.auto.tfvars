resourceGroupName = "ArtistAnywhere.Farm" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

######################################################################################################
# Virtual Machine Scale Sets (https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) #
######################################################################################################

virtualMachineScaleSets = [
  {
    name    = "LnxFarmGPU"
    imageId = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/Linux/versions/1.1.0"
    machine = {
      size  = "Standard_NV36ads_A10_v5"
      count = 2
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
      userName            = ""
      userPassword        = ""
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.sh"
      parameters = {
        fileSystemMountsStorage = [
          "azrender1.blob.core.windows.net:/azrender1/data /mnt/data/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        fileSystemMountsStorageCache = [
          "cache.artist.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
        ]
        fileSystemMountsQube = [
          "scheduler.artist.studio:/Qube /mnt/qube nfs defaults 0 0"
        ]
        fileSystemMountsDeadline = [
          "scheduler.artist.studio:/Deadline /mnt/deadline nfs defaults 0 0"
        ]
        fileSystemPermissions = [
          "chmod 777 /mnt/data/read",
          "chmod 777 /mnt/data/write"
        ]
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable          = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy  = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      machineMaxPrice = -1       # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    terminationNotification = {  # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable                   = true
      timeoutDelay             = "PT5M"
      detectionIntervalSeconds = 5
    }
  },
  {
    name    = "" # "LnxFarmCPU"
    imageId = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/Linux/versions/1.0.0"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 2
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
      userName            = ""
      userPassword        = ""
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.sh"
      parameters = {
        fileSystemMountsStorage = [
          "azrender1.blob.core.windows.net:/azrender1/data /mnt/data/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        fileSystemMountsStorageCache = [
          "cache.artist.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
        ]
        fileSystemMountsQube = [
          "scheduler.artist.studio:/Qube /mnt/qube nfs defaults 0 0"
        ]
        fileSystemMountsDeadline = [
          "scheduler.artist.studio:/Deadline /mnt/deadline nfs defaults 0 0"
        ]
        fileSystemPermissions = [
          "chmod 777 /mnt/data/read",
          "chmod 777 /mnt/data/write"
        ]
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable          = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy  = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      machineMaxPrice = -1       # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    terminationNotification = {  # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable       = true
      timeoutDelay = "PT5M"
    }
  },
  {
    name    = "" # "WinFarmGPU"
    imageId = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/WinFarm/versions/1.1.0"
    machine = {
      size  = "Standard_NV36ads_A10_v5"
      count = 2
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
      userName            = ""
      userPassword        = ""
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMountsStorage = [
          "mount -o anon nolock \\\\azrender1.blob.core.windows.net\\azrender1\\data W:"
        ]
        fileSystemMountsStorageCache = [
          "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data R:"
        ]
        fileSystemMountsQube = [
          "mount -o anon \\\\scheduler.artist.studio\\Qube S:"
        ]
        fileSystemMountsDeadline = [
          "mount -o anon \\\\scheduler.artist.studio\\Deadline T:"
        ]
        fileSystemPermissions = [
          "icacls R: /grant Everyone:F",
          "icacls W: /grant Everyone:F"
        ]
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable          = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy  = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      machineMaxPrice = -1       # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    terminationNotification = {  # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable       = true
      timeoutDelay = "PT5M"
    }
  },
  {
    name    = "" # "WinFarmCPU"
    imageId = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/WinFarm/versions/1.0.0"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 2
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
      userName            = ""
      userPassword        = ""
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMountsStorage = [
          "mount -o anon nolock \\\\azrender1.blob.core.windows.net\\azrender1\\data W:"
        ]
        fileSystemMountsStorageCache = [
          "mount -o anon nolock \\\\cache.artist.studio\\mnt\\data R:"
        ]
        fileSystemMountsQube = [
          "mount -o anon \\\\scheduler.artist.studio\\Qube S:"
        ]
        fileSystemMountsDeadline = [
          "mount -o anon \\\\scheduler.artist.studio\\Deadline T:"
        ]
        fileSystemPermissions = [
          "icacls R: /grant Everyone:F",
          "icacls W: /grant Everyone:F"
        ]
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable          = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy  = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      machineMaxPrice = -1       # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    terminationNotification = {  # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable       = true
      timeoutDelay = "PT5M"
    }
  }
]

#######################################################################
# Kubernetes (https://learn.microsoft.com/azure/aks/intro-kubernetes) #
#######################################################################

kubernetes = {
  fleet = { # https://learn.microsoft.com/azure/kubernetes-fleet/overview
    name      = ""
    dnsPrefix = ""
  }
  clusters = [
    {
      name      = "cluster1"
      dnsPrefix = ""
      defaultPool = {
        name = "default"
        machine = {
          size  = "Standard_HB120rs_v2"
          count = 2
        }
      }
    },
    {
      name      = "cluster2"
      dnsPrefix = ""
      defaultPool = {
        name = "default"
        machine = {
          size  = "Standard_HB120rs_v2"
          count = 2
        }
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

managedIdentity = {
  name              = ""
  resourceGroupName = ""
}

keyVault = {
  name                 = ""
  resourceGroupName    = ""
  keyNameAdminUsername = ""
  keyNameAdminPassword = ""
}

monitorWorkspace = {
  name              = ""
  resourceGroupName = ""
}
