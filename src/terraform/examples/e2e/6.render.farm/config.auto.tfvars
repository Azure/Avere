resourceGroupName = "ArtistAnywhere.Farm"

######################################################################################################
# Virtual Machine Scale Sets (https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) #
######################################################################################################

virtualMachineScaleSets = [
  {
    name    = "LnxFarm"
    imageId = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/Linux/versions/1.0.0"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 2
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
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.sh"
      parameters = {
        fileSystemMountsStorage = [
          "azrender1.blob.core.windows.net:/azrender1/show /mnt/show/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        fileSystemMountsStorageCache = [
          # "cache.artist.studio:/mnt/show /mnt/show/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
        ]
        fileSystemMountsRoyalRender = [
        ]
        fileSystemMountsDeadline = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0"
        ]
        fileSystemPermissions = [
          "chmod 777 /mnt/show/write"
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
    enableAcceleratedNetworking = true
  },
  {
    name    = "" # "WinFarm"
    imageId = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/WinFarm/versions/1.0.0"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 2
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
      sshPublicKey        = "" # "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      enable   = true
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMountsStorage = [
          "mount -o anon nolock \\\\azrender1.blob.core.windows.net\\azrender1\\show W:"
        ]
        fileSystemMountsStorageCache = [
          # "mount -o anon nolock \\\\cache.artist.studio\\mnt\\show R:"
        ]
        fileSystemMountsRoyalRender = [
        ]
        fileSystemMountsDeadline = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:"
        ]
        fileSystemPermissions = [
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
    enableAcceleratedNetworking = true
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
# Optional resource dependency configuration for existing deployments #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
