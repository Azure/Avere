resourceGroupName = "ArtistAnywhere.Workstation" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

virtualMachines = [
  {
    name        = "LnxArtist"
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/Linux/versions/2.0.0"
    machineSize = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
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
      fileName = "initialize.sh"
      parameters = {
        fileSystemMountsStorage = [
          "azrender1.blob.core.windows.net:/azrender1/data /mnt/data nfs sec=sys,vers=3,proto=tcp,nolock 0 0"
        ]
        fileSystemMountsStorageCache = [
        ]
        fileSystemMountsRoyalRender = [
          "render.artist.studio:/rr /rr nfs defaults 0 0"
        ]
        fileSystemMountsDeadline = [
          "render.artist.studio:/deadline /deadline nfs defaults 0 0"
        ]
        teradiciLicenseKey = ""
      }
    }
    monitorExtension = {
      enable = false
    }
  },
  {
    name        = "WinArtist"
    imageId     = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azrender/images/WinArtist/versions/2.0.0"
    machineSize = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/virtual-machines/sizes
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
      fileName = "initialize.ps1"
      parameters = {
        fileSystemMountsStorage = [
          "mount -o anon nolock \\\\azrender1.blob.core.windows.net\\azrender1\\data W:"
        ]
        fileSystemMountsStorageCache = [
        ]
        fileSystemMountsRoyalRender = [
          "mount -o anon \\\\render.artist.studio\\RoyalRender S:"
        ]
        fileSystemMountsDeadline = [
          "mount -o anon \\\\render.artist.studio\\Deadline S:"
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
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

computeNetwork = {
  name              = ""
  subnetName        = ""
  resourceGroupName = ""
}
