resourceGroupName = "AzureRender.Farm"

# Virtual Machine Scale Sets - https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview
virtualMachineScaleSets = [
  {
    name           = ""
    hostNamePrefix = "" // https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set#computer_name_prefix
    imageId        = "" // https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries#image-versions
    nodeSizeSku    = "" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    nodeCount      = 0
    osType         = "Linux"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadOnly"
      ephemeralEnable = true // https://docs.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks
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
  },
  {
    name           = ""
    hostNamePrefix = "" // https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set#computer_name_prefix
    imageId        = "" // https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries#image-versions
    nodeSizeSku    = "" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    nodeCount      = 0
    osType         = "Windows"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadOnly"
      ephemeralEnable = true // https://docs.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks
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
  }
]
