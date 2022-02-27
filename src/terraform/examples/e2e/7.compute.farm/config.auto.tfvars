resourceGroupName = "AzureRender.Farm"

# Virtual Machine Scale Sets (https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview)
virtualMachineScaleSets = [
  {
    name    = "LinuxFarm"
    imageId = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/LinuxFarm/versions/1.0.0"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 10
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        ephemeralEnable = true // https://docs.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks
      }
    }
    networkInterface = {
      enableAcceleratedNetworking = false
    }
    adminLogin = {
      userName     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.sh"
      parameters = {
        fileSystemMounts = [
          "cache.media.studio:/mnt/farm /mnt/show/read nfs hard,proto=tcp,mountproto=tcp,retry=30 0 0",
          "azmedia1.blob.core.windows.net:/azmedia1/show /mnt/show/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0",
          "scheduler.media.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0"
        ]
      }
    }
    monitorExtension = {
      enable = true
    }
    spot = {                     // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy  = "Delete" // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      machineMaxPrice = -1       // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    terminateNotification = {    // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable       = true
      timeoutDelay = "PT5M"
      eventHandler = "terminate.sh"
    }
    bootDiagnostics = {
      storageAccountUri = ""
    }
  },
  {
    name    = ""
    imageId = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/WindowsFarm/versions/1.0.0"
    machine = {
      size  = "Standard_HB120rs_v2"
      count = 10
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        ephemeralEnable = true // https://docs.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks
      }
    }
    networkInterface = {
      enableAcceleratedNetworking = false
    }
    adminLogin = {
      userName     = "azadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    customExtension = {
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMounts = [
          "mount -o anon \\\\cache.media.studio\\mnt\\farm R:",
          "mount -o anon -o sec=sys -o nolock \\\\azmedia1.blob.core.windows.net\\azmedia1\\show W:",
          "mount -o anon \\\\scheduler.media.studio\\DeadlineRepository S:"
        ]
      }
    }
    monitorExtension = {
      enable = true
    }
    spot = {                     // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy  = "Delete" // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      machineMaxPrice = -1       // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    terminateNotification = {    // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
      enable       = true
      timeoutDelay = "PT5M"
      eventHandler = "terminate.ps1"
    }
    bootDiagnostics = {
      storageAccountUri = ""
    }
  }
]

# Virtual Network (https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
virtualNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
