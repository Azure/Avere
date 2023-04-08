resourceGroupName = "ArtistAnywhere.Farm" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

######################################################################################################
# Virtual Machine Scale Sets (https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) #
######################################################################################################

virtualMachineScaleSets = [
  {
    name = "LnxFarmG"
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
      fileName = "initialize.sh"
      parameters = {
        fileSystemMountsStorage = [
          "azstudio1.blob.core.windows.net:/azstudio1/data /mnt/data/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        fileSystemMountsStorageCache = [
          "cache.content.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
        ]
        fileSystemMountsRoyalRender = [
          "render.content.studio:/rr /rr nfs defaults 0 0"
        ]
        fileSystemMountsDeadline = [
          "render.content.studio:/deadline /deadline nfs defaults 0 0"
        ]
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    terminationNotification = {  # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable                   = true
      timeoutDelay             = "PT5M"
      detectionIntervalSeconds = 5
    }
  },
  {
    name = "" # "LnxFarmC"
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
      fileName = "initialize.sh"
      parameters = {
        fileSystemMountsStorage = [
          "azstudio1.blob.core.windows.net:/azstudio1/data /mnt/data/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        fileSystemMountsStorageCache = [
          "cache.content.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
        ]
        fileSystemMountsRoyalRender = [
          "render.content.studio:/rr /rr nfs defaults 0 0"
        ]
        fileSystemMountsDeadline = [
          "render.content.studio:/deadline /deadline nfs defaults 0 0"
        ]
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    terminationNotification = {  # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
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
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMountsStorage = [
          "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\data W:"
        ]
        fileSystemMountsStorageCache = [
          "mount -o anon nolock \\\\cache.content.studio\\mnt\\data R:"
        ]
        fileSystemMountsRoyalRender = [
          "mount -o anon \\\\render.content.studio\\RoyalRender S:"
        ]
        fileSystemMountsDeadline = [
          "mount -o anon \\\\render.content.studio\\Deadline S:"
        ]
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    terminationNotification = {  # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
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
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMountsStorage = [
          "mount -o anon nolock \\\\azstudio1.blob.core.windows.net\\azstudio1\\data W:"
        ]
        fileSystemMountsStorageCache = [
          "mount -o anon nolock \\\\cache.content.studio\\mnt\\data R:"
        ]
        fileSystemMountsRoyalRender = [
          "mount -o anon \\\\render.content.studio\\RoyalRender S:"
        ]
        fileSystemMountsDeadline = [
          "mount -o anon \\\\render.content.studio\\Deadline S:"
        ]
      }
    }
    monitorExtension = {
      enable = false
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    terminationNotification = {  # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable                   = true
      timeoutDelay             = "PT5M"
      detectionIntervalSeconds = 5
    }
  }
]

#######################################################################
# Kubernetes (https://learn.microsoft.com/azure/aks/intro-kubernetes) #
#######################################################################

kubernetes = {
  fleet = {    # https://learn.microsoft.com/azure/kubernetes-fleet/overview
    name      = "" # "azstudio"
    dnsPrefix = ""
  }
  clusters = [ # https://learn.microsoft.com/azure/aks/intro-kubernetes
    {
      name      = "" # "cpu"
      dnsPrefix = ""
      systemNodePool = {
        name = "sys"
        machine = {
          size  = "Standard_D8s_v5"
          count = 2
        }
      }
      userNodePools = [
        {
          name = "app"
          machine = {
            size  = "Standard_HB120rs_v2"
            count = 2
          }
          spot = {
            enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
            evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
          }
        }
      ]
    },
    {
      name      = "" # "gpu"
      dnsPrefix = ""
      systemNodePool = {
        name = "sys"
        machine = {
          size  = "Standard_D8s_v5"
          count = 2
        }
      }
      userNodePools = [
        {
          name = "app"
          machine = {
            size  = "Standard_NV36ads_A10_v5"
            count = 2
          }
          spot = {
            enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
            evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
          }
        }
      ]
    }
  ]
}

servicePassword = "P@ssword1234"

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
