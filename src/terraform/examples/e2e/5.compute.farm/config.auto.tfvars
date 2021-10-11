resourceGroupName = "AzureRender.Farm"

# Virtual Machine Scale Sets - https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview
virtualMachineScaleSets = [
  {
    name           = "Linux"
    hostNamePrefix = "HPC"
    imageId        = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/LinuxFarm/versions/1.0.0"
    nodeSizeSku    = "Standard_HB120rs_v3"
    nodeCount      = 1
    osType         = "Linux"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadOnly"
      ephemeralEnable = false // https://docs.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks
    }
    adminLogin = {
      username     = "azureadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    spot = {                    // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      maxNodePrice   = -1       // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    script = {
      file = "initialize/extension.sh"
      parameters = {
        fileSystemMounts = [
          "cache.media.studio:/show /mnt/show nfs defaults 0 0"
        ]
      }
    }
  },
  {
    name           = ""
    hostNamePrefix = "HPC"
    imageId        = "/subscriptions/3d07cfbc-17aa-41b4-baa1-488fef85a1d3/resourceGroups/AzureRender.Image/providers/Microsoft.Compute/galleries/Gallery/images/WindowsFarm/versions/1.0.0"
    nodeSizeSku    = "Standard_HB120rs_v3"
    nodeCount      = 1
    osType         = "Windows"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadOnly"
      ephemeralEnable = false // https://docs.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks
    }
    adminLogin = {
      username     = "azureadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
    spot = {                    // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot#eviction-policy
      maxNodePrice   = -1       // https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/use-spot#pricing
    }
    script = {
      file = "initialize/extension.ps1"
      parameters = {
        fileSystemMounts = []
      }
    }
  }
]
