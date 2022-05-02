terraform {
  required_version = ">= 1.1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.4.0"
    }
  }
  backend "azurerm" {
    key = "07.compute.farm"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine_scale_set {
      force_delete                  = false
      roll_instances_when_required  = true
      scale_to_zero_before_deletion = true
    }    
  }
}

module "global" {
  source = "../00.global"
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
                fileSystemMounts      = list(string)
                fileSystemPermissions = list(string)
              }
            )
          }
        )
        monitorExtension = object(
          {
            enable = bool
          }
        )
        spot = object(
          {
            enable          = bool
            evictionPolicy  = string
            machineMaxPrice = number
          }
        )
        terminationNotification = object(
          {
            enable       = bool
            timeoutDelay = string
            eventHandler = string
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
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "02.network"
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

data "azurerm_log_analytics_workspace" "monitor" {
  name                = module.global.monitorWorkspaceName
  resource_group_name = module.global.securityResourceGroupName
}

resource "azurerm_role_assignment" "farm" {
  role_definition_name = "Virtual Machine Contributor" // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  scope                = azurerm_resource_group.farm.id
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
  priority                        = each.value.spot.enable ? "Spot" : "Regular"
  eviction_policy                 = each.value.spot.enable ? each.value.spot.evictionPolicy : null
  max_bid_price                   = each.value.spot.enable ? each.value.spot.machineMaxPrice : -1
  single_placement_group          = false
  overprovision                   = false
  custom_data = base64gzip(
    templatefile(each.value.terminationNotification.eventHandler, {})
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
  dynamic "extension" {
    for_each = each.value.monitorExtension.enable ? [1] : [] 
    content {
      name                       = "Monitor"
      type                       = "OmsAgentForLinux"
      publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
      type_handler_version       = "1.13"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        workspaceId: data.azurerm_log_analytics_workspace.monitor.workspace_id
      })
      protected_settings = jsonencode({
        workspaceKey: data.azurerm_log_analytics_workspace.monitor.primary_shared_key
      })
    }
  }
  dynamic "termination_notification" {
    for_each = each.value.terminationNotification.enable ? [1] : [] 
    content {
      enabled = each.value.terminationNotification.enable
      timeout = each.value.terminationNotification.timeoutDelay
    }
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
  priority               = each.value.spot.enable ? "Spot" : "Regular"
  eviction_policy        = each.value.spot.enable ? each.value.spot.evictionPolicy : null
  max_bid_price          = each.value.spot.enable ? each.value.spot.machineMaxPrice : -1
  single_placement_group = false
  overprovision          = false
  custom_data = base64gzip(
    templatefile(each.value.terminationNotification.eventHandler, {})
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
  dynamic "extension" {
    for_each = each.value.monitorExtension.enable ? [1] : [] 
    content {
      name                       = "Monitor"
      type                       = "MicrosoftMonitoringAgent"
      publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        workspaceId: data.azurerm_log_analytics_workspace.monitor.workspace_id
      })
      protected_settings = jsonencode({
        workspaceKey: data.azurerm_log_analytics_workspace.monitor.primary_shared_key
      })
    }
  }
  dynamic "termination_notification" {
    for_each = each.value.terminationNotification.enable ? [1] : [] 
    content {
      enabled = each.value.terminationNotification.enable
      timeout = each.value.terminationNotification.timeoutDelay
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
