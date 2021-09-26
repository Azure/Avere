resourceGroupName = "AzureRender.Workstation"

# Virtual Machines - https://docs.microsoft.com/en-us/azure/virtual-machines/
virtualMachines = [
  {
    name     = ""
    hostName = "" // https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine#computer_name
    imageId  = "" // https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries#image-versions
    sizeSku  = "" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    osType   = "Linux"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadWrite"
    }
    adminLogin = {
      username     = "azureadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
  },
  {
    name     = ""
    hostName = "" // https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine#computer_name
    imageId  = "" // https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries#image-versions
    sizeSku  = "" // https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
    osType   = "Windows"
    osDisk = {
      storageType = "Standard_LRS"
      cachingType = "ReadWrite"
    }
    adminLogin = {
      username     = "azureadmin"
      sshPublicKey = "" // "ssh-rsa ..."
      disablePasswordAuthentication = false
    }
  }
]
