terraform {
  required_version = ">= 1.4.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.60.0"
    }
  }
  backend "azurerm" {
    key = "7.Render.Farm"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine_scale_set {
      force_delete                  = false
      roll_instances_when_required  = true
      scale_to_zero_before_deletion = true
    }
  }
}

module "global" {
  source = "../0.Global.Foundation/module"
}

variable "resourceGroupName" {
  type = string
}

variable "virtualMachineScaleSets" {
  type = list(object(
    {
      name = string
      machine = object(
        {
          size  = string
          count = number
          image = object(
            {
              id = string
              plan = object(
                {
                  publisher = string
                  product   = string
                  name      = string
                }
              )
            }
          )
        }
      )
      network = object(
        {
          enableAcceleration = bool
        }
      )
      operatingSystem = object(
        {
          type = string
          disk = object(
            {
              storageType = string
              cachingType = string
              sizeGB      = number
              ephemeral = object(
                {
                  enable    = bool
                  placement = string
                }
              )
            }
          )
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
      customExtension = object(
        {
          enable   = bool
          name     = string
          fileName = string
          parameters = object(
            {
              fileSystemMounts = list(object(
                {
                  enable = bool
                  mount  = string
                }
              ))
              terminateNotification = object(
                {
                  enable       = bool
                  delayTimeout = string
                }
              )
            }
          )
        }
      )
      healthExtension = object(
        {
          enable      = bool
          protocol    = string
          port        = number
          requestPath = string
        }
      )
      monitorExtension = object(
        {
          enable = bool
        }
      )
      spot = object(
        {
          enable         = bool
          evictionPolicy = string
        }
      )
    }
  ))
}

variable "serviceAccount" {
  type = object(
    {
      name     = string
      password = string
    }
  )
}

variable "computeNetwork" {
  type = object(
    {
      name              = string
      subnetName        = string
      resourceGroupName = string
    }
  )
}

data "azurerm_user_assigned_identity" "studio" {
  name                = module.global.managedIdentity.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault" "studio" {
  count               = module.global.keyVault.name != "" ? 1 : 0
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "admin_username" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.adminUsername
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_key_vault_secret" "admin_password" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.adminPassword
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_key_vault_secret" "service_password" {
  count        = module.global.keyVault.name != "" ? 1 : 0
  name         = module.global.keyVault.secretName.servicePassword
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_log_analytics_workspace" "monitor" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = module.global.monitor.name
  resource_group_name = module.global.resourceGroupName
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "1.Virtual.Network"
  }
}

data "terraform_remote_state" "image" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "3.Image.Builder"
  }
}

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "farm" {
  name                 = !local.stateExistsNetwork ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.farm].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_private_dns_zone" "studio" {
  name                = data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

locals {
  stateExistsNetwork = var.computeNetwork.name != "" ? false : try(length(data.terraform_remote_state.network.outputs) > 0, false)
  virtualMachineScaleSetsLinux = [
    for virtualMachineScaleSet in var.virtualMachineScaleSets : merge(virtualMachineScaleSet, {
      machine = {
        size  = virtualMachineScaleSet.machine.size
        count = virtualMachineScaleSet.machine.count
        image = {
          id = virtualMachineScaleSet.machine.image.id
          plan = {
            publisher = lower(virtualMachineScaleSet.machine.image.plan.publisher != "" ? virtualMachineScaleSet.machine.image.plan.publisher : try(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].publisher, ""))
            product   = lower(virtualMachineScaleSet.machine.image.plan.product != "" ? virtualMachineScaleSet.machine.image.plan.product : try(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].offer, ""))
            name      = lower(virtualMachineScaleSet.machine.image.plan.name != "" ? virtualMachineScaleSet.machine.image.plan.name : try(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].sku, ""))
          }
        }
      }
    }) if virtualMachineScaleSet.name != "" && virtualMachineScaleSet.operatingSystem.type == "Linux"
  ]
  serviceAccountPassword = var.serviceAccount.password != "" ? var.serviceAccount.password : data.azurerm_key_vault_secret.service_password[0].value
}

resource "azurerm_resource_group" "farm" {
  name     = var.resourceGroupName
  location = module.global.regionNames[0]
}

resource "azurerm_linux_virtual_machine_scale_set" "farm" {
  for_each = {
    for virtualMachineScaleSet in local.virtualMachineScaleSetsLinux : virtualMachineScaleSet.name => virtualMachineScaleSet
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.farm.name
  location                        = azurerm_resource_group.farm.location
  sku                             = each.value.machine.size
  instances                       = each.value.machine.count
  source_image_id                 = each.value.machine.image.id
  admin_username                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : each.value.adminLogin.userName
  admin_password                  = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : each.value.adminLogin.userPassword
  disable_password_authentication = each.value.adminLogin.passwordAuth.disable
  priority                        = each.value.spot.enable ? "Spot" : "Regular"
  eviction_policy                 = each.value.spot.enable ? each.value.spot.evictionPolicy : null
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
    enable_accelerated_networking = each.value.network.enableAcceleration
  }
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
    disk_size_gb         = each.value.operatingSystem.disk.sizeGB
    dynamic diff_disk_settings {
      for_each = each.value.operatingSystem.disk.ephemeral.enable ? [1] : []
      content {
        option    = "Local"
        placement = each.value.operatingSystem.disk.ephemeral.placement
      }
    }
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  dynamic plan {
    for_each = each.value.machine.image.plan.name != "" ? [1] : []
    content {
      publisher = each.value.machine.image.plan.publisher
      product   = each.value.machine.image.plan.product
      name      = each.value.machine.image.plan.name
    }
  }
  dynamic admin_ssh_key {
    for_each = each.value.adminLogin.sshPublicKey != "" ? [1] : []
    content {
      username   = each.value.adminLogin.userName
      public_key = each.value.adminLogin.sshPublicKey
    }
  }
  dynamic extension {
    for_each = each.value.customExtension.enable ? [1] : []
    content {
      name                       = each.value.customExtension.name
      type                       = "CustomScript"
      publisher                  = "Microsoft.Azure.Extensions"
      type_handler_version       = "2.1"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        script: "${base64encode(
          templatefile(each.value.customExtension.fileName, merge(each.value.customExtension.parameters, {
            renderManager          = module.global.renderManager
            serviceAccountName     = var.serviceAccount.name
            serviceAccountPassword = local.serviceAccountPassword
          }))
        )}"
      })
    }
  }
  dynamic extension {
    for_each = each.value.healthExtension.enable ? [1] : []
    content {
      name                       = "Health"
      type                       = "ApplicationHealthLinux"
      publisher                  = "Microsoft.ManagedServices"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        protocol    = each.value.healthExtension.protocol
        port        = each.value.healthExtension.port
        requestPath = each.value.healthExtension.requestPath
      })
    }
  }
  dynamic extension {
    for_each = each.value.monitorExtension.enable && module.global.monitor.name != "" ? [1] : []
    content {
      name                       = "Monitor"
      type                       = "AzureMonitorLinuxAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type_handler_version       = "1.21"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        workspaceId = data.azurerm_log_analytics_workspace.monitor[0].workspace_id
      })
      protected_settings = jsonencode({
        workspaceKey = data.azurerm_log_analytics_workspace.monitor[0].primary_shared_key
      })
    }
  }
  dynamic termination_notification {
    for_each = each.value.customExtension.parameters.terminateNotification.enable ? [1] : []
    content {
      enabled = each.value.customExtension.parameters.terminateNotification.enable
      timeout = each.value.customExtension.parameters.terminateNotification.delayTimeout
    }
  }
}

resource "azurerm_windows_virtual_machine_scale_set" "farm" {
  for_each = {
    for virtualMachineScaleSet in var.virtualMachineScaleSets : virtualMachineScaleSet.name => virtualMachineScaleSet if virtualMachineScaleSet.name != "" && virtualMachineScaleSet.operatingSystem.type == "Windows"
  }
  name                   = each.value.name
  resource_group_name    = azurerm_resource_group.farm.name
  location               = azurerm_resource_group.farm.location
  sku                    = each.value.machine.size
  instances              = each.value.machine.count
  source_image_id        = each.value.machine.image.id
  admin_username         = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_username[0].value : each.value.adminLogin.userName
  admin_password         = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.admin_password[0].value : each.value.adminLogin.userPassword
  priority               = each.value.spot.enable ? "Spot" : "Regular"
  eviction_policy        = each.value.spot.enable ? each.value.spot.evictionPolicy : null
  custom_data            = base64encode(templatefile("../0.Global.Foundation/functions.ps1", {}))
  single_placement_group = false
  overprovision          = false
  network_interface {
    name    = each.value.name
    primary = true
    ip_configuration {
      name      = "ipConfig"
      primary   = true
      subnet_id = data.azurerm_subnet.farm.id
    }
    enable_accelerated_networking = each.value.network.enableAcceleration
  }
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
    disk_size_gb         = each.value.operatingSystem.disk.sizeGB
    dynamic diff_disk_settings {
      for_each = each.value.operatingSystem.disk.ephemeral.enable ? [1] : []
      content {
        option    = "Local"
        placement = each.value.operatingSystem.disk.ephemeral.placement
      }
    }
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  dynamic extension {
    for_each = each.value.customExtension.enable ? [1] : []
    content {
      name                       = each.value.customExtension.name
      type                       = "CustomScriptExtension"
      publisher                  = "Microsoft.Compute"
      type_handler_version       = "1.10"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        commandToExecute = "PowerShell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(
          templatefile(each.value.customExtension.fileName, merge(each.value.customExtension.parameters, {
            renderManager          = module.global.renderManager
            serviceAccountName     = var.serviceAccount.name
            serviceAccountPassword = local.serviceAccountPassword
          })), "UTF-16LE"
        )}"
      })
    }
  }
  dynamic extension {
    for_each = each.value.healthExtension.enable ? [1] : []
    content {
      name                       = "Health"
      type                       = "ApplicationHealthWindows"
      publisher                  = "Microsoft.ManagedServices"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        protocol    = each.value.healthExtension.protocol
        port        = each.value.healthExtension.port
        requestPath = each.value.healthExtension.requestPath
      })
    }
  }
  dynamic extension {
    for_each = each.value.monitorExtension.enable && module.global.monitor.name != "" ? [1] : []
    content {
      name                       = "Monitor"
      type                       = "AzureMonitorWindowsAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type_handler_version       = "1.7"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        workspaceId = data.azurerm_log_analytics_workspace.monitor[0].workspace_id
      })
      protected_settings = jsonencode({
        workspaceKey = data.azurerm_log_analytics_workspace.monitor[0].primary_shared_key
      })
    }
  }
  dynamic termination_notification {
    for_each = each.value.customExtension.parameters.terminateNotification.enable ? [1] : []
    content {
      enabled = each.value.customExtension.parameters.terminateNotification.enable
      timeout = each.value.customExtension.parameters.terminateNotification.delayTimeout
    }
  }
}

output "resourceGroupName" {
  value = azurerm_resource_group.farm.name
}

output "virtualMachineScaleSets" {
  value = var.virtualMachineScaleSets
}
