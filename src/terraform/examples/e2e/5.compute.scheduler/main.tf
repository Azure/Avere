terraform {
  required_version = ">= 1.0.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.81.0"
    }
  }
  backend "azurerm" {
    key = "5.compute.scheduler"
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
            username     = string
            sshPublicKey = string
            disablePasswordAuthentication = bool
          }
        )
        scriptExtension = object(
          {
            fileName   = string
            parameters = object(
              {
              }
            )
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
  name                 = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.virtualNetwork.subnets[data.terraform_remote_state.network[0].outputs.virtualNetworkSubnetIndexFarm].name : var.virtualNetwork.subnetName
  resource_group_name  = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.resourceGroupName : var.virtualNetwork.resourceGroupName
  virtual_network_name = var.virtualNetwork.name == "" ? data.terraform_remote_state.network[0].outputs.virtualNetwork.name : var.virtualNetwork.name
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

locals {
  customScriptFileInput  = "C:\\\\AzureData\\\\CustomData.bin"
  customScriptFileOutput = "C:\\\\AzureData\\\\CustomData.ps1"
  customScriptFileCreate = "$inputStream = New-Object System.IO.FileStream ${local.customScriptFileInput}, ([System.IO.FileMode]::Open), ([System.IO.FileAccess]::Read), ([System.IO.FileShare]::Read) ; $streamReader = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)) ; Out-File -InputObject $streamReader.ReadToEnd() -FilePath ${local.customScriptFileOutput}"
}

resource "azurerm_resource_group" "scheduler" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_network_interface" "scheduler" {
  for_each = {
    for x in var.virtualMachines : x.name => x if x.name != ""
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.scheduler.name
  location            = azurerm_resource_group.scheduler.location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.farm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "scheduler" {
  for_each = {
    for x in var.virtualMachines : x.name => x if x.name != "" && x.operatingSystem.type == "Linux"
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.scheduler.name
  location                        = azurerm_resource_group.scheduler.location
  source_image_id                 = each.value.imageId
  size                            = each.value.machineSize
  admin_username                  = each.value.adminLogin.username
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuthentication
  network_interface_ids = [
    "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
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
    azurerm_network_interface.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "scheduler_linux" {
  for_each = {
    for x in var.virtualMachines : x.name => x if x.name != "" && x.scriptExtension.fileName != "" && x.operatingSystem.type == "Linux" 
  }
  name                       = "Custom"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = <<SETTINGS
    {
      "script": "${base64encode(
        templatefile(each.value.scriptExtension.fileName, each.value.scriptExtension.parameters)
      )}"
    }
  SETTINGS
  depends_on = [
    azurerm_linux_virtual_machine.scheduler
  ]
}

resource "azurerm_windows_virtual_machine" "scheduler" {
  for_each = {
    for x in var.virtualMachines : x.name => x if x.name != "" && x.operatingSystem.type == "Windows" 
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.scheduler.name
  location            = azurerm_resource_group.scheduler.location
  source_image_id     = each.value.imageId
  size                = each.value.machineSize
  admin_username      = each.value.adminLogin.username
  admin_password      = data.azurerm_key_vault_secret.admin_password.value
  network_interface_ids = [
    "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity.id]
  }
  custom_data = each.value.scriptExtension.fileName == "" ? null : base64gzip(
    templatefile(each.value.scriptExtension.fileName, each.value.scriptExtension.parameters)
  )
  depends_on = [
    azurerm_network_interface.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "scheduler_windows" {
  for_each = {
    for x in var.virtualMachines : x.name => x if x.name != "" && x.scriptExtension.fileName != "" && x.operatingSystem.type == "Windows" 
  }
  name                       = "Custom"
  type                       = "CustomScriptExtension"
  publisher                  = "Microsoft.Compute"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = <<SETTINGS
    {
      "commandToExecute": "PowerShell -ExecutionPolicy Unrestricted -Command \"& {${local.customScriptFileCreate}}\" ; PowerShell -ExecutionPolicy Unrestricted -File ${local.customScriptFileOutput}"
    }
  SETTINGS
  depends_on = [
    azurerm_windows_virtual_machine.scheduler
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
