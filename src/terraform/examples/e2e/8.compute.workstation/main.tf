terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.24.0"
    }
  }
  backend "azurerm" {
    key = "8.compute.workstation"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

module "global" {
  source = "../0.global"
}

variable "resourceGroupName" {
  type = string
}

variable "virtualMachines" {
  type = list(object(
    {
      name        = string
      imageId     = string
      machineSize = string
      operatingSystem = object(
        {
          type = string
          disk = object(
            {
              storageType = string
              cachingType = string
            }
          )
        }
      )
      adminLogin = object(
        {
          userName            = string
          sshPublicKey        = string
          disablePasswordAuth = bool
        }
      )
      customExtension = object(
        {
          enabled  = bool
          fileName = string
          parameters = object(
            {
              fileSystemMounts   = list(string)
              teradiciLicenseKey = string
            }
          )
        }
      )
      monitorExtension = object(
        {
          enabled = bool
        }
      )
    }
  ))
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

data "terraform_remote_state" "network" {
  count   = local.useDependencyConfig ? 0 : 1
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
  }
}

data "azurerm_virtual_network" "compute" {
  name                 = local.useDependencyConfig ? var.computeNetwork.name : data.terraform_remote_state.network[0].outputs.computeNetwork.name
  resource_group_name  = local.useDependencyConfig ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network[0].outputs.resourceGroupName
}

data "azurerm_subnet" "workstation" {
  name                 = local.useDependencyConfig ? var.computeNetwork.subnetName : data.terraform_remote_state.network[0].outputs.computeNetwork.subnets[data.terraform_remote_state.network[0].outputs.computeNetworkSubnetIndex.workstation].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

locals {
  useDependencyConfig = var.computeNetwork.name != ""
}

resource "azurerm_resource_group" "workstation" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_network_interface" "workstation" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != ""
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
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.operatingSystem.type == "Linux"
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.workstation.name
  location                        = azurerm_resource_group.workstation.location
  source_image_id                 = each.value.imageId
  size                            = each.value.machineSize
  admin_username                  = each.value.adminLogin.userName
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuth
  network_interface_ids = [
    "${azurerm_resource_group.workstation.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity.id]
  }
  boot_diagnostics {
    storage_account_uri = null
  }
  dynamic "admin_ssh_key" {
    for_each = each.value.adminLogin.sshPublicKey == "" ? [] : [1]
    content {
      username   = each.value.adminLogin.userName
      public_key = each.value.adminLogin.sshPublicKey
    }
  }
  depends_on = [
    azurerm_network_interface.workstation
  ]
}

resource "azurerm_virtual_machine_extension" "custom_linux" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.customExtension.enabled && virtualMachine.operatingSystem.type == "Linux"
  }
  name                       = "Custom"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.workstation.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "script": "${base64encode(
      templatefile(each.value.customExtension.fileName, each.value.customExtension.parameters)
    )}"
  })
  depends_on = [
    azurerm_linux_virtual_machine.workstation
  ]
}

resource "azurerm_virtual_machine_extension" "monitor_linux" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.monitorExtension.enabled && virtualMachine.operatingSystem.type == "Linux"
  }
  name                       = "Monitor"
  type                       = "AzureMonitorLinuxAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type_handler_version       = "1.21"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.workstation.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "workspaceId": data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings = jsonencode({
    "workspaceKey": data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })
  depends_on = [
    azurerm_linux_virtual_machine.workstation
  ]
}

resource "azurerm_windows_virtual_machine" "workstation" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.operatingSystem.type == "Windows"
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.workstation.name
  location            = azurerm_resource_group.workstation.location
  source_image_id     = each.value.imageId
  size                = each.value.machineSize
  admin_username      = each.value.adminLogin.userName
  admin_password      = data.azurerm_key_vault_secret.admin_password.value
  network_interface_ids = [
    "${azurerm_resource_group.workstation.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity.id]
  }
  boot_diagnostics {
    storage_account_uri = null
  }
  depends_on = [
    azurerm_network_interface.workstation
  ]
}

resource "azurerm_virtual_machine_extension" "custom_windows" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.customExtension.enabled && virtualMachine.operatingSystem.type == "Windows"
  }
  name                       = "Custom"
  type                       = "CustomScriptExtension"
  publisher                  = "Microsoft.Compute"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.workstation.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "commandToExecute": "PowerShell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(
      templatefile(each.value.customExtension.fileName, each.value.customExtension.parameters), "UTF-16LE"
    )}"
  })
  depends_on = [
    azurerm_windows_virtual_machine.workstation
  ]
}

resource "azurerm_virtual_machine_extension" "monitor_windows" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.monitorExtension.enabled && virtualMachine.operatingSystem.type == "Windows"
  }
  name                       = "Monitor"
  type                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type_handler_version       = "1.7"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.workstation.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "workspaceId": data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings = jsonencode({
    "workspaceKey": data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })
  depends_on = [
    azurerm_windows_virtual_machine.workstation
  ]
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "virtualMachines" {
  value = var.virtualMachines
}
