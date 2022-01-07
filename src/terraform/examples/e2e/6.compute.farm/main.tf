terraform {
  required_version = ">= 1.1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.91.0"
    }
  }
  backend "azurerm" {
    key = "6.compute.farm"
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
        name    = string
        imageId = string
        machine = object (
          {
            size  = string
            count = number
          }
        )
        operatingSystem = object(
          {
            type = string
            disk = object(
              {
                storageType     = string
                cachingType     = string
                ephemeralEnable = bool
              }
            )
          }
        )
        networkInterface = object(
          {
            enableAcceleratedNetworking = bool
          }
        )
        adminLogin = object(
          {
            userName     = string
            sshPublicKey = string
            disablePasswordAuthentication = bool
          }
        )
        customExtension = object(
          {
            fileName = string
            parameters = object(
              {
                fileSystemMounts = list(string)
              }
            )
          }
        )
        spot = object(
          {
            evictionPolicy  = string
            machineMaxPrice = number
          }
        )
        terminateNotification = object(
          {
            enable       = bool
            timeoutDelay = string
            eventHandler = string
          }
        )
        bootDiagnostics = object(
          {
            storageAccountUri = string
          }
        )
      }
    )
  )
}

variable "virtualNetwork" {
  type = object(
    {
      name              = string
      subnetName        = string
      resourceGroupName = string
    }
  )
}

data "terraform_remote_state" "network" {
  count   = var.virtualNetwork.name == "" ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.terraformStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "1.network"
  }
}

data "azurerm_virtual_network" "network" {
  name                 = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.virtualNetwork.name : var.virtualNetwork.name
  resource_group_name  = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.resourceGroupName : var.virtualNetwork.resourceGroupName
}

data "azurerm_subnet" "farm" {
  name                 = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets[data.terraform_remote_state.network[0].outputs.virtualNetworkSubnetIndex.farm].name : var.virtualNetwork.subnetName
  resource_group_name  = data.azurerm_virtual_network.network.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.network.name
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
    for x in var.virtualMachineScaleSets : x.name => x if x.name != "" && x.operatingSystem.type == "Linux"
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.farm.name
  location                        = azurerm_resource_group.farm.location
  source_image_id                 = each.value.imageId
  sku                             = each.value.machine.size
  instances                       = each.value.machine.count
  admin_username                  = each.value.adminLogin.userName
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuthentication
  priority                        = each.value.spot.evictionPolicy != "" ? "Spot" : "Regular"
  eviction_policy                 = each.value.spot.evictionPolicy != "" ? each.value.spot.evictionPolicy : null
  max_bid_price                   = each.value.spot.evictionPolicy != "" ? each.value.spot.machineMaxPrice : -1
  single_placement_group          = false
  overprovision                   = false
  custom_data = base64gzip(
    templatefile(each.value.terminateNotification.eventHandler, {})
  )
  network_interface {
    name    = each.value.name
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = data.azurerm_subnet.farm.id
    }
    enable_accelerated_networking = false
  }
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
    dynamic "diff_disk_settings" {
      for_each = each.value.operatingSystem.disk.ephemeralEnable ? [1] : [] 
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
      username   = each.value.adminLogin.userName
      public_key = each.value.adminLogin.sshPublicKey
    }
  }
  dynamic "extension" {
    for_each = each.value.customExtension.fileName != "" ? [1] : []
    content {
      name                       = "Custom"
      type                       = "CustomScript"
      publisher                  = "Microsoft.Azure.Extensions"
      type_handler_version       = "2.1"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        script: "${base64encode(
          templatefile(each.value.customExtension.fileName, each.value.customExtension.parameters)
        )}"
      })
    }
  }
  dynamic "terminate_notification" {
    for_each = each.value.terminateNotification.enable ? [1] : [] 
    content {
      enabled = each.value.terminateNotification.enable
      timeout = each.value.terminateNotification.timeoutDelay
    }
  }
  boot_diagnostics {
    storage_account_uri = each.value.bootDiagnostics.storageAccountUri
  }
}

resource "azurerm_windows_virtual_machine_scale_set" "farm" {
  for_each = {
    for x in var.virtualMachineScaleSets : x.name => x if x.name != "" && x.operatingSystem.type == "Windows"
  }
  name                   = each.value.name
  resource_group_name    = azurerm_resource_group.farm.name
  location               = azurerm_resource_group.farm.location
  source_image_id        = each.value.imageId
  sku                    = each.value.machine.size
  instances              = each.value.machine.count
  admin_username         = each.value.adminLogin.userName
  admin_password         = data.azurerm_key_vault_secret.admin_password.value
  priority               = each.value.spot.evictionPolicy != "" ? "Spot" : "Regular"
  eviction_policy        = each.value.spot.evictionPolicy != "" ? each.value.spot.evictionPolicy : null
  max_bid_price          = each.value.spot.evictionPolicy != "" ? each.value.spot.machineMaxPrice : -1
  single_placement_group = false
  overprovision          = false
  custom_data = base64gzip(
    templatefile(each.value.terminateNotification.eventHandler, {})
  )
  network_interface {
    name    = each.value.name
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = data.azurerm_subnet.farm.id
    }
    enable_accelerated_networking = each.value.networkInterface.enableAcceleratedNetworking
  }
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
    dynamic "diff_disk_settings" {
      for_each = each.value.operatingSystem.disk.ephemeralEnable ? [1] : [] 
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
    for_each = each.value.customExtension.fileName != "" ? [1] : [] 
    content {
      name                       = "Custom"
      type                       = "CustomScriptExtension"
      publisher                  = "Microsoft.Compute"
      type_handler_version       = "1.10"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        commandToExecute: "PowerShell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(
          templatefile(each.value.customExtension.fileName, each.value.customExtension.parameters), "UTF-16LE"
        )}"
      })
    }
  }
  dynamic "terminate_notification" {
    for_each = each.value.terminateNotification.enable ? [1] : [] 
    content {
      enabled = each.value.terminateNotification.enable
      timeout = each.value.terminateNotification.timeoutDelay
    }
  }
  boot_diagnostics {
    storage_account_uri = each.value.bootDiagnostics.storageAccountUri
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
