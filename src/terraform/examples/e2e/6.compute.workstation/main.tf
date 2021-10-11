terraform {
  required_version = ">= 1.0.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.80.0"
    }
  }
  backend "azurerm" {
    key = "6.compute.workstation"
  }
}

provider "azurerm" {
  features {}
}

module "global" {
  source = "../global"
}

variable "resourceGroupName" {
  type = string
}

variable "virtualMachines" {
  type = list(
    object(
      {
        name     = string
        hostName = string
        imageId  = string
        sizeSku  = string
        osType   = string
        osDisk = object(
          {
            storageType = string
            cachingType = string
          }
        )
        adminLogin = object(
          {
            username     = string
            sshPublicKey = string
            disablePasswordAuthentication = bool
          }
        )
      }
    )
  )
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.terraformStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "1.network"
  }
}

data "azurerm_subnet" "workstation" {
  name                 = data.terraform_remote_state.network.outputs.virtualNetworkSubnetNameWorkstation
  resource_group_name  = data.terraform_remote_state.network.outputs.resourceGroupName
  virtual_network_name = data.terraform_remote_state.network.outputs.virtualNetworkName
}

data "azurerm_user_assigned_identity" "identity" {
  name                = module.global.managedIdentityName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault" "vault" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = module.global.keyVaultSecretNameAdminPassword
  key_vault_id = data.azurerm_key_vault.vault.id
}

resource "azurerm_resource_group" "workstation" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_network_interface" "workstation" {
  for_each = {
    for x in var.virtualMachines : x.name => x if x.name != ""
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.workstation.name
  location            = azurerm_resource_group.workstation.location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.workstation.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "workstation" {
  for_each = {
    for x in var.virtualMachines : x.name => x if x.name != "" && x.osType == "Linux"
  }
  name                            = each.value.name
  computer_name                   = each.value.hostName != "" ? each.value.hostName : null
  resource_group_name             = azurerm_resource_group.workstation.name
  location                        = azurerm_resource_group.workstation.location
  source_image_id                 = each.value.imageId
  size                            = each.value.sizeSku
  admin_username                  = each.value.adminLogin.username
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuthentication
  network_interface_ids = [
    "${azurerm_resource_group.workstation.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.osDisk.storageType
    caching              = each.value.osDisk.cachingType
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity.id]
  }
  dynamic "admin_ssh_key" {
    for_each = each.value.adminLogin.sshPublicKey == "" ? [] : [1] 
    content {
      username   = each.value.adminLogin.username
      public_key = each.value.adminLogin.sshPublicKey
    }
  }
  depends_on = [
    azurerm_network_interface.workstation
  ]
}

resource "azurerm_windows_virtual_machine" "workstation" {
  for_each = {
    for x in var.virtualMachines : x.name => x if x.name != "" && x.osType == "Windows"
  }
  name                = each.value.name
  computer_name       = each.value.hostName != "" ? each.value.hostName : null
  resource_group_name = azurerm_resource_group.workstation.name
  location            = azurerm_resource_group.workstation.location
  source_image_id     = each.value.imageId
  size                = each.value.sizeSku
  admin_username      = each.value.adminLogin.username
  admin_password      = data.azurerm_key_vault_secret.admin_password.value
  network_interface_ids = [
    "${azurerm_resource_group.workstation.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.osDisk.storageType
    caching              = each.value.osDisk.cachingType
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity.id]
  }
  depends_on = [
    azurerm_network_interface.workstation
  ]
}

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "virtualMachines" {
  value = var.virtualMachines
}
