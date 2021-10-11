terraform {
  required_version = ">= 1.0.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.80.0"
    }
  }
  backend "azurerm" {
    key = "5.compute.farm"
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

variable "virtualMachineScaleSets" {
  type = list(
    object(
      {
        name           = string
        hostNamePrefix = string
        imageId        = string
        nodeSizeSku    = string
        nodeCount      = number
        osType         = string
        osDisk = object(
          {
            storageType     = string
            cachingType     = string
            ephemeralEnable = bool
          }
        )
        adminLogin = object(
          {
            username     = string
            sshPublicKey = string
            disablePasswordAuthentication = bool
          }
        )
        spot = object(
          {
            evictionPolicy = string
            maxNodePrice   = number
          }
        )
        script = object(
          {
            file       = string
            parameters = object(
              {
                fileSystemMounts = list(string)
              }
            )
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

data "azurerm_subnet" "farm" {
  name                 = data.terraform_remote_state.network.outputs.virtualNetworkSubnetNameFarm
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

resource "azurerm_resource_group" "farm" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_linux_virtual_machine_scale_set" "farm" {
  for_each = {
    for x in var.virtualMachineScaleSets : x.name => x if x.name != "" && x.osType == "Linux"
  }
  name                            = each.value.name
  computer_name_prefix            = each.value.hostNamePrefix
  resource_group_name             = azurerm_resource_group.farm.name
  location                        = azurerm_resource_group.farm.location
  source_image_id                 = each.value.imageId
  sku                             = each.value.nodeSizeSku
  instances                       = each.value.nodeCount
  admin_username                  = each.value.adminLogin.username
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuthentication
  priority                        = each.value.spot.evictionPolicy != "" ? "Spot" : "Regular"
  eviction_policy                 = each.value.spot.evictionPolicy != "" ? each.value.spot.evictionPolicy : null
  max_bid_price                   = each.value.spot.evictionPolicy != "" ? each.value.spot.maxNodePrice : -1
  single_placement_group          = false
  overprovision                   = false
  network_interface {
    name    = each.value.name
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = data.azurerm_subnet.farm.id
    }
  }
  os_disk {
    storage_account_type = each.value.osDisk.storageType
    caching              = each.value.osDisk.cachingType
    dynamic "diff_disk_settings" {
      for_each = each.value.osDisk.ephemeralEnable ? [1] : [] 
      content {
        option = "Local"
      }
    }
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
  dynamic "extension" {
    for_each = each.value.script.file == "" ? [] : [1] 
    content {
      name                       = "Custom"
      type                       = "CustomScript"
      publisher                  = "Microsoft.Azure.Extensions"
      type_handler_version       = "2.1"
      auto_upgrade_minor_version = true
      settings = <<SETTINGS
        {
          "script": "${base64encode(
            templatefile(each.value.script.file, each.value.script.parameters)
          )}"
        }
      SETTINGS
    }
  }
}

resource "azurerm_windows_virtual_machine_scale_set" "farm" {
  for_each = {
    for x in var.virtualMachineScaleSets : x.name => x if x.name != "" && x.osType == "Windows"
  }
  name                            = each.value.name
  computer_name_prefix            = each.value.hostNamePrefix
  resource_group_name             = azurerm_resource_group.farm.name
  location                        = azurerm_resource_group.farm.location
  source_image_id                 = each.value.imageId
  sku                             = each.value.nodeSizeSku
  instances                       = each.value.nodeCount
  admin_username                  = each.value.adminLogin.username
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  priority                        = each.value.spot.evictionPolicy != "" ? "Spot" : "Regular"
  eviction_policy                 = each.value.spot.evictionPolicy != "" ? each.value.spot.evictionPolicy : null
  max_bid_price                   = each.value.spot.evictionPolicy != "" ? each.value.spot.maxNodePrice : -1
  single_placement_group          = false
  overprovision                   = false
  network_interface {
    name    = each.value.name
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = data.azurerm_subnet.farm.id
    }
  }
  os_disk {
    storage_account_type = each.value.osDisk.storageType
    caching              = each.value.osDisk.cachingType
    dynamic "diff_disk_settings" {
      for_each = each.value.osDisk.ephemeralEnable ? [1] : [] 
      content {
        option = "Local"
      }
    }
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity.id]
  }
  dynamic "extension" {
    for_each = each.value.script.file == "" ? [] : [1] 
    content {
      name                       = "Custom"
      type                       = "CustomScriptExtension"
      publisher                  = "Microsoft.Compute"
      type_handler_version       = "1.10"
      auto_upgrade_minor_version = true
      settings = <<SETTINGS
        {
          "script": "${base64encode(
            templatefile(each.value.script.file, each.value.script.parameters)
          )}"
        }
      SETTINGS
    }
  }
}

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "virtualMachineScaleSets" {
  value = var.virtualMachineScaleSets
}
