resourceGroupName = "ArtistAnywhere.Farm"

# Virtual Machine Scale Sets (https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview)
virtualMachineScaleSets = [
  {
    name    = "LnxFarm"
    imageId = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/1.0.0"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 10
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        ephemeralEnable = true // https://docs.microsoft.com/azure/virtual-machines/ephemeral-os-disks
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0",
          "azrender1.blob.core.windows.net:/azrender1/show /mnt/show/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0",
          "cache.artist.studio:/mnt/show/farm /mnt/show/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
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
      enable = true              // https://docs.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy  = "Delete" // https://docs.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      machineMaxPrice = -1       // https://docs.microsoft.com/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    terminationNotification = {  // https://docs.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable       = true
      timeoutDelay = "PT5M"
    }
  },
  {
    name    = "" // WinFarm
    imageId = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinFarm/versions/1.0.0"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 10
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        ephemeralEnable = true // https://docs.microsoft.com/azure/virtual-machines/ephemeral-os-disks
      }
    }
    adminLogin = {
      userName            = "azadmin"
      sshPublicKey        = "" // "ssh-rsa ..."
      disablePasswordAuth = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:",
          "mount -o anon nolock \\\\azrender1.blob.core.windows.net\\azrender1\\show W:",
          "mount -o anon nolock \\\\cache.artist.studio\\mnt\\farm R:"
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
      enable = true              // https://docs.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy  = "Delete" // https://docs.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      machineMaxPrice = -1       // https://docs.microsoft.com/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    terminationNotification = {  // https://docs.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable       = true
      timeoutDelay = "PT5M"
    }
  }
]

# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
