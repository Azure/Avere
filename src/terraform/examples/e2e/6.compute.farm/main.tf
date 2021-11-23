terraform {
  required_version = ">= 1.0.10"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.86.0"
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
        adminLogin = object(
          {
            username     = string
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
        monitorExtension = object(
          {
            enable = bool
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
            enable         = bool
            timeoutMinutes = string
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

data "azurerm_key_vault_secret" "user_password" {
  name         = module.global.keyVaultSecretNameUserPassword
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_log_analytics_workspace" "monitor" {
  name                = module.global.monitorWorkspaceName
  resource_group_name = module.global.securityResourceGroupName
}

locals {
  customScriptFileInput  = "C:\\AzureData\\CustomData.bin"
  customScriptFileOutput = "C:\\AzureData\\CustomData.ps1"
  customScriptFileCreate = "$inputStream = New-Object System.IO.FileStream ${local.customScriptFileInput}, ([System.IO.FileMode]::Open), ([System.IO.FileAccess]::Read), ([System.IO.FileShare]::Read) ; $streamReader = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)) ; Out-File -InputObject $streamReader.ReadToEnd() -FilePath ${local.customScriptFileOutput}"
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
  admin_username                  = each.value.adminLogin.username
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuthentication
  priority                        = each.value.spot.evictionPolicy != "" ? "Spot" : "Regular"
  eviction_policy                 = each.value.spot.evictionPolicy != "" ? each.value.spot.evictionPolicy : null
  max_bid_price                   = each.value.spot.evictionPolicy != "" ? each.value.spot.machineMaxPrice : -1
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
      username   = each.value.adminLogin.username
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
          templatefile(each.value.customExtension.fileName, merge(each.value.customExtension.parameters, {userPassword: "${data.azurerm_key_vault_secret.user_password.value}"}))
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
  dynamic "terminate_notification" {
    for_each = each.value.terminateNotification.enable ? [1] : [] 
    content {
      enabled = each.value.terminateNotification.enable
      timeout = each.value.terminateNotification.timeoutMinutes
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
  admin_username         = each.value.adminLogin.username
  admin_password         = data.azurerm_key_vault_secret.admin_password.value
  priority               = each.value.spot.evictionPolicy != "" ? "Spot" : "Regular"
  eviction_policy        = each.value.spot.evictionPolicy != "" ? each.value.spot.evictionPolicy : null
  max_bid_price          = each.value.spot.evictionPolicy != "" ? each.value.spot.machineMaxPrice : -1
  single_placement_group = false
  overprovision          = false
  custom_data = each.value.customExtension.fileName == "" ? null : base64gzip(
    templatefile(each.value.customExtension.fileName, merge(each.value.customExtension.parameters, {userPassword: "${data.azurerm_key_vault_secret.user_password.value}"}))
  )
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
        commandToExecute: "PowerShell -ExecutionPolicy Unrestricted -Command \"& {${local.customScriptFileCreate}}\" ; PowerShell -ExecutionPolicy Unrestricted -File ${local.customScriptFileOutput}"
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
  dynamic "terminate_notification" {
    for_each = each.value.terminateNotification.enable ? [1] : [] 
    content {
      enabled = each.value.terminateNotification.enable
      timeout = each.value.terminateNotification.timeoutMinutes
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
