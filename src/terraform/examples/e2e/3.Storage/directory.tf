#################################################################################################################################################
# Active Directory (https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview) #
#################################################################################################################################################

variable "activeDirectory" {
  type = object(
    {
      enable = bool
      machine = object(
        {
          name    = string
          size    = string
          imageId = string
        }
      )
      network = object(
        {
          enableAcceleration = bool
        }
      )
      osDisk = object(
        {
          storageType = string
          cachingType = string
          sizeGB      = number
        }
      )
      adminLogin = object(
        {
          userName     = string
          userPassword = string
          sshPublicKey = string
          passwordAuth = object(
            {
              disable = bool
            }
          )
        }
      )
    }
  )
}


resource "azurerm_resource_group" "directory" {
  count    = var.activeDirectory.enable ? 1 : 0
  name     = "${var.resourceGroupName}.Directory"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_network_interface" "directory" {
  count               = var.activeDirectory.enable ? 1 : 0
  name                = var.activeDirectory.machine.name
  resource_group_name = azurerm_resource_group.directory[0].name
  location            = azurerm_resource_group.directory[0].location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = local.virtualNetworkSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
  enable_accelerated_networking = var.activeDirectory.network.enableAcceleration
}

resource "azurerm_windows_virtual_machine" "directory" {
  count               = var.activeDirectory.enable ? 1 : 0
  name                = var.activeDirectory.machine.name
  resource_group_name = azurerm_resource_group.directory[0].name
  location            = azurerm_resource_group.directory[0].location
  source_image_id     = var.activeDirectory.machine.imageId
  size                = var.activeDirectory.machine.size
  admin_username      = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : var.activeDirectory.adminLogin.userName
  admin_password      = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : var.activeDirectory.adminLogin.userPassword
  network_interface_ids = [
    azurerm_network_interface.directory[0].id
  ]
  os_disk {
    storage_account_type = var.activeDirectory.osDisk.storageType
    caching              = var.activeDirectory.osDisk.cachingType
    disk_size_gb         = var.activeDirectory.osDisk.sizeGB
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
}
