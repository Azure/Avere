resourceGroupName = "ArtistAnywhere.Workstation"

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    name = "LnxArtist"
    image = {
      id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/Linux/versions/2.0.0"
      plan = {
        name      = ""
        product   = ""
        publisher = ""
      }
    }
    machineSize = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
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
        fileSystemMounts = [
          "scheduler.artist.studio:/DeadlineRepository /mnt/scheduler nfs defaults 0 0",
          "azrender1.blob.core.windows.net:/azrender1/show /mnt/show nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name = "WinArtist"
    image = {
      id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/Gallery/images/WinArtist/versions/2.0.0"
      plan = {
        name      = ""
        product   = ""
        publisher = ""
      }
    }
    machineSize = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Premium_LRS"
        cachingType = "ReadWrite"
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
        fileSystemMounts = [
          "mount -o anon \\\\scheduler.artist.studio\\DeadlineRepository S:",
          "mount -o anon nolock \\\\azrender1.blob.core.windows.net\\azrender1\\show W:"
        ]
        teradiciLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
    }
  }
]

#######################################################################
# Optional resource dependency configuration for existing deployments #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}