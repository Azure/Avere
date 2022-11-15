terraform {
  required_version = ">= 1.3.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.31.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.30.0"
    }
  }
  backend "azurerm" {
    key = "6.compute.scheduler"
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

variable "batchAccount" {
  type = object(
    {
      enable = bool
      name   = string
      storageAccount = object(
        {
          name              = string
          resourceGroupName = string
        }
      )
      encryption = object(
        {
          enable = bool
        }
      )
    }
  )
}

variable "virtualMachines" {
  type = list(object(
    {
      name = string
      image = object(
        {
          id = string
          plan = object(
            {
              name      = string
              product   = string
              publisher = string
            }
          )
        }
      )
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
          enable   = bool
          fileName = string
          parameters = object(
            {
              fileSystemMounts = list(string)
              autoScale = object(
                {
                  enable                   = bool
                  fileName                 = string
                  scaleSetName             = string
                  resourceGroupName        = string
                  detectionIntervalSeconds = number
                  jobWaitThresholdSeconds  = number
                  workerIdleDeleteSeconds  = number
                }
              )
              cycleCloud = object(
                {
                  enable             = bool
                  storageAccountName = string
                }
              )
            }
          )
        }
      )
      monitorExtension = object(
        {
          enable = bool
        }
      )
    }
  ))
}

variable "computeNetwork" {
  type = object(
    {
      name               = string
      subnetName         = string
      resourceGroupName  = string
      privateDnsZoneName = string
    }
  )
}

variable "computeGallery" {
  type = object(
    {
      name                  = string
      resourceGroupName     = string
      imageVersionIdDefault = string
    }
  )
}

data "azurerm_client_config" "current" {}

data "azurerm_user_assigned_identity" "solution" {
  name                = module.global.managedIdentityName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault" "solution" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "admin_username" {
  name         = module.global.keyVaultSecretNameAdminUsername
  key_vault_id = data.azurerm_key_vault.solution.id
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = module.global.keyVaultSecretNameAdminPassword
  key_vault_id = data.azurerm_key_vault.solution.id
}

data "azurerm_key_vault_key" "batch_encryption" {
  name         = module.global.keyVaultKeyNameBatchEncryption
  key_vault_id = data.azurerm_key_vault.solution.id
}

data "azurerm_log_analytics_workspace" "monitor" {
  name                = module.global.monitorWorkspaceName
  resource_group_name = module.global.securityResourceGroupName
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "2.network"
  }
}

data "terraform_remote_state" "image" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "5.compute.image"
  }
}

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "farm" {
  name                 = !local.stateExistsNetwork ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetworkSubnetIndex.farm].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_private_dns_zone" "network" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.privateDnsZoneName : data.terraform_remote_state.network.outputs.privateDns.zoneName
  resource_group_name = data.azurerm_virtual_network.compute.resource_group_name
}

data "azuread_service_principal" "batch" {
  display_name = "Microsoft Azure Batch"
}

locals {
  stateExistsNetwork     = try(length(data.terraform_remote_state.network.outputs) >= 0, false)
  stateExistsImage       = try(length(data.terraform_remote_state.image.outputs) >= 0, false)
  imageGalleryName       = !local.stateExistsImage ? var.computeGallery.name : data.terraform_remote_state.image.outputs.imageGallery.name
  imageResourceGroupName = !local.stateExistsImage ? var.computeGallery.resourceGroupName : data.terraform_remote_state.image.outputs.resourceGroupName
  imageVersionIdDefault  = !local.stateExistsImage ? var.computeGallery.imageVersionIdDefault : "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.imageResourceGroupName}/providers/Microsoft.Compute/galleries/${local.imageGalleryName}/images/Linux/versions/0.0.0"
  virtualMachinesLinux = [
    for virtualMachine in var.virtualMachines : merge(virtualMachine, {
      image = {
        id = virtualMachine.image.id
        plan = {
          name      = lower(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].sku)
          product   = lower(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].offer)
          publisher = lower(data.terraform_remote_state.image.outputs.imageDefinitionsLinux[0].publisher)
        }
      }
    }) if virtualMachine.operatingSystem.type == "Linux"
  ]
  schedulerMachineNames = [
    for virtualMachine in var.virtualMachines : virtualMachine.name if virtualMachine.name != ""
  ]
}

resource "azurerm_resource_group" "scheduler" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_role_assignment" "batch" {
  count                = var.batchAccount.enable ? 1 : 0
  role_definition_name = "Contributor"
  principal_id         = data.azuread_service_principal.batch.object_id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

resource "azurerm_batch_account" "scheduler" {
  count                               = var.batchAccount.enable ? 1 : 0
  name                                = var.batchAccount.name
  resource_group_name                 = azurerm_resource_group.scheduler.name
  location                            = azurerm_resource_group.scheduler.location
  storage_account_id                  = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.batchAccount.storageAccount.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${var.batchAccount.storageAccount.name}"
  storage_account_node_identity       = data.azurerm_user_assigned_identity.solution.id
  storage_account_authentication_mode = "BatchAccountManagedIdentity"
  pool_allocation_mode                = "UserSubscription"
  public_network_access_enabled       = false
  allowed_authentication_modes = [
    "AAD",
    "TaskAuthenticationToken"
  ]
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.solution.id
    ]
  }
  key_vault_reference {
    id  = data.azurerm_key_vault.solution.id
    url = data.azurerm_key_vault.solution.vault_uri
  }
  dynamic encryption {
    for_each = var.batchAccount.encryption.enable ? [1] : [0]
    content {
      key_vault_key_id = data.azurerm_key_vault_key.batch_encryption.id
    }
  }
  depends_on = [
    azurerm_role_assignment.batch
  ]
}

resource "azurerm_network_interface" "scheduler" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && !var.batchAccount.enable
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
    for virtualMachine in local.stateExistsImage ? local.virtualMachinesLinux : var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.operatingSystem.type == "Linux" && !var.batchAccount.enable
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.scheduler.name
  location                        = azurerm_resource_group.scheduler.location
  source_image_id                 = each.value.image.id
  size                            = each.value.machineSize
  admin_username                  = each.value.adminLogin.userName
  admin_password                  = data.azurerm_key_vault_secret.admin_password.value
  disable_password_authentication = each.value.adminLogin.disablePasswordAuth
  custom_data = base64encode(
    templatefile(each.value.customExtension.parameters.autoScale.fileName, each.value.customExtension.parameters)
  )
  network_interface_ids = [
    "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.solution.id
    ]
  }
  boot_diagnostics {
    storage_account_uri = null
  }
  dynamic plan {
    for_each = each.value.image.plan.name == "" ? [] : [1]
    content {
      name      = each.value.image.plan.name
      product   = each.value.image.plan.product
      publisher = each.value.image.plan.publisher
    }
  }
  dynamic admin_ssh_key {
    for_each = each.value.adminLogin.sshPublicKey == "" ? [] : [1]
    content {
      username   = each.value.adminLogin.userName
      public_key = each.value.adminLogin.sshPublicKey
    }
  }
  depends_on = [
    azurerm_network_interface.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "custom_linux" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.customExtension.enable && virtualMachine.operatingSystem.type == "Linux" && !var.batchAccount.enable
  }
  name                       = "Custom"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "script": "${base64encode(
      templatefile(each.value.customExtension.fileName, merge(each.value.customExtension.parameters,
        { tenantId                 = data.azurerm_client_config.current.tenant_id },
        { subscriptionId           = data.azurerm_client_config.current.subscription_id },
        { regionName               = module.global.regionName },
        { networkResourceGroupName = data.azurerm_virtual_network.compute.resource_group_name },
        { networkName              = data.azurerm_virtual_network.compute.name },
        { networkSubnetName        = data.azurerm_subnet.farm.name },
        { imageResourceGroupName   = local.imageResourceGroupName },
        { imageGalleryName         = local.imageGalleryName },
        { imageVersionIdDefault    = local.imageVersionIdDefault },
        { adminUsername            = data.azurerm_key_vault_secret.admin_username.value },
        { adminPassword            = data.azurerm_key_vault_secret.admin_password.value }
      ))
    )}"
  })
  depends_on = [
    azurerm_linux_virtual_machine.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "monitor_linux" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.monitorExtension.enable && virtualMachine.operatingSystem.type == "Linux" && !var.batchAccount.enable
  }
  name                       = "Monitor"
  type                       = "AzureMonitorLinuxAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type_handler_version       = "1.21"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "workspaceId": data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings = jsonencode({
    "workspaceKey": data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })
  depends_on = [
    azurerm_linux_virtual_machine.scheduler
  ]
}

resource "azurerm_windows_virtual_machine" "scheduler" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.operatingSystem.type == "Windows" && !var.batchAccount.enable
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.scheduler.name
  location            = azurerm_resource_group.scheduler.location
  source_image_id     = each.value.image.id
  size                = each.value.machineSize
  admin_username      = each.value.adminLogin.userName
  admin_password      = data.azurerm_key_vault_secret.admin_password.value
  custom_data = base64encode(
    templatefile(each.value.customExtension.parameters.autoScale.fileName, each.value.customExtension.parameters)
  )
  network_interface_ids = [
    "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.solution.id
    ]
  }
  boot_diagnostics {
    storage_account_uri = null
  }
  dynamic plan {
    for_each = each.value.image.plan.name == "" ? [] : [1]
    content {
      name      = each.value.image.plan.name
      product   = each.value.image.plan.product
      publisher = each.value.image.plan.publisher
    }
  }
  depends_on = [
    azurerm_network_interface.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "custom_windows" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.customExtension.enable && virtualMachine.operatingSystem.type == "Windows" && !var.batchAccount.enable
  }
  name                       = "Custom"
  type                       = "CustomScriptExtension"
  publisher                  = "Microsoft.Compute"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "commandToExecute": "PowerShell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(
      templatefile(each.value.customExtension.fileName, each.value.customExtension.parameters), "UTF-16LE"
    )}"
  })
  depends_on = [
    azurerm_windows_virtual_machine.scheduler
  ]
}

resource "azurerm_virtual_machine_extension" "monitor_windows" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.name != "" && virtualMachine.monitorExtension.enable && virtualMachine.operatingSystem.type == "Windows" && !var.batchAccount.enable
  }
  name                       = "Monitor"
  type                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type_handler_version       = "1.7"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.scheduler.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    "workspaceId": data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings = jsonencode({
    "workspaceKey": data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })
  depends_on = [
    azurerm_windows_virtual_machine.scheduler
  ]
}

resource "azurerm_private_dns_a_record" "scheduler" {
  count               = !var.batchAccount.enable ? 1 : 0
  name                = "scheduler"
  resource_group_name = data.azurerm_private_dns_zone.network.resource_group_name
  zone_name           = data.azurerm_private_dns_zone.network.name
  ttl                 = 300
  records = [
    azurerm_network_interface.scheduler[local.schedulerMachineNames[0]].private_ip_address
  ]
}

resource "azurerm_role_assignment" "cycle_cloud" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.customExtension.parameters.cycleCloud.enable && !var.batchAccount.enable
  }
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_user_assigned_identity.solution.principal_id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "virtualMachines" {
  value = var.virtualMachines
}

output "privateDnsRecord" {
  value = azurerm_private_dns_a_record.scheduler
}
