######################################################################################################
# Virtual Machine Scale Sets (https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) #
######################################################################################################

variable "virtualMachineScaleSets" {
  type = list(object(
    {
      enable = bool
      name   = string
      machine = object(
        {
          size  = string
          count = number
          image = object(
            {
              id = string
              plan = object(
                {
                  enable    = bool
                  publisher = string
                  product   = string
                  name      = string
                }
              )
            }
          )
        }
      )
      spot = object(
        {
          enable         = bool
          evictionPolicy = string
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
      activeDirectory = object(
        {
          enable           = bool
          domainName       = string
          domainServerName = string
          orgUnitPath      = string
          adminUsername    = string
          adminPassword    = string
        }
      )
      extension = object(
        {
          initialize = object(
            {
              enable   = bool
              fileName = string
              parameters = object(
                {
                  fileSystems = list(object(
                    {
                      enable = bool
                      mounts = list(string)
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
          health = object (
            {
              enable      = bool
              protocol    = string
              port        = number
              requestPath = string
            }
          )
          monitor = object (
            {
              enable = bool
            }
          )
        }
      )
    }
  ))
}

locals {
  virtualMachineScaleSets = [
    for virtualMachineScaleSet in var.virtualMachineScaleSets : merge(virtualMachineScaleSet,
      {
        adminLogin = {
          userName     = virtualMachineScaleSet.adminLogin.userName != "" ? virtualMachineScaleSet.adminLogin.userName : try(data.azurerm_key_vault_secret.admin_username[0].value, "")
          userPassword = virtualMachineScaleSet.adminLogin.userPassword != "" ? virtualMachineScaleSet.adminLogin.userPassword : try(data.azurerm_key_vault_secret.admin_password[0].value, "")
          sshPublicKey = virtualMachineScaleSet.adminLogin.sshPublicKey
          passwordAuth = {
            disable = virtualMachineScaleSet.adminLogin.passwordAuth.disable
          }
        }
        activeDirectory = {
          enable           = virtualMachineScaleSet.activeDirectory.enable
          domainName       = virtualMachineScaleSet.activeDirectory.domainName
          domainServerName = virtualMachineScaleSet.activeDirectory.domainServerName
          orgUnitPath      = virtualMachineScaleSet.activeDirectory.orgUnitPath
          adminUsername    = virtualMachineScaleSet.activeDirectory.adminUsername != "" ? virtualMachineScaleSet.activeDirectory.adminUsername : try(data.azurerm_key_vault_secret.admin_username[0].value, "")
          adminPassword    = virtualMachineScaleSet.activeDirectory.adminPassword != "" ? virtualMachineScaleSet.activeDirectory.adminPassword : try(data.azurerm_key_vault_secret.admin_password[0].value, "")
        }
      }
    )
  ]
}

resource "azurerm_linux_virtual_machine_scale_set" "farm" {
  for_each = {
    for virtualMachineScaleSet in local.virtualMachineScaleSets : virtualMachineScaleSet.name => virtualMachineScaleSet if virtualMachineScaleSet.enable && virtualMachineScaleSet.operatingSystem.type == "Linux"
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.farm.name
  location                        = azurerm_resource_group.farm.location
  sku                             = each.value.machine.size
  instances                       = each.value.machine.count
  source_image_id                 = each.value.machine.image.id
  admin_username                  = each.value.adminLogin.userName
  admin_password                  = each.value.adminLogin.userPassword
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
    for_each = each.value.machine.image.plan.enable ? [1] : []
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
    for_each = each.value.extension.initialize.enable ? [1] : []
    content {
      name                       = "Initialize"
      type                       = "CustomScript"
      publisher                  = "Microsoft.Azure.Extensions"
      type_handler_version       = "2.1"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        script: "${base64encode(
          templatefile(each.value.extension.initialize.fileName, merge(each.value.extension.initialize.parameters,
            {
              activeDirectory = each.value.activeDirectory
            }
          ))
        )}"
      })
    }
  }
  dynamic extension {
    for_each = each.value.extension.health.enable ? [1] : []
    content {
      name                       = "Health"
      type                       = "ApplicationHealthLinux"
      publisher                  = "Microsoft.ManagedServices"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        protocol    = each.value.extension.health.protocol
        port        = each.value.extension.health.port
        requestPath = each.value.extension.health.requestPath
      })
    }
  }
  dynamic extension {
    for_each = each.value.extension.monitor.enable && module.global.monitor.enable ? [1] : []
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
    for_each = each.value.extension.initialize.parameters.terminateNotification.enable ? [1] : []
    content {
      enabled = each.value.extension.initialize.parameters.terminateNotification.enable
      timeout = each.value.extension.initialize.parameters.terminateNotification.delayTimeout
    }
  }
}

resource "azurerm_windows_virtual_machine_scale_set" "farm" {
  for_each = {
    for virtualMachineScaleSet in local.virtualMachineScaleSets : virtualMachineScaleSet.name => virtualMachineScaleSet if virtualMachineScaleSet.enable && virtualMachineScaleSet.operatingSystem.type == "Windows"
  }
  name                   = each.value.name
  resource_group_name    = azurerm_resource_group.farm.name
  location               = azurerm_resource_group.farm.location
  sku                    = each.value.machine.size
  instances              = each.value.machine.count
  source_image_id        = each.value.machine.image.id
  admin_username         = each.value.adminLogin.userName
  admin_password         = each.value.adminLogin.userPassword
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
    for_each = each.value.extension.initialize.enable ? [1] : []
    content {
      name                       = "Initialize"
      type                       = "CustomScriptExtension"
      publisher                  = "Microsoft.Compute"
      type_handler_version       = "1.10"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        commandToExecute = "PowerShell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(
          templatefile(each.value.extension.initialize.fileName, merge(each.value.extension.initialize.parameters,
            {
              activeDirectory = each.value.activeDirectory
            }
          )), "UTF-16LE"
        )}"
      })
    }
  }
  dynamic extension {
    for_each = each.value.extension.health.enable ? [1] : []
    content {
      name                       = "Health"
      type                       = "ApplicationHealthWindows"
      publisher                  = "Microsoft.ManagedServices"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings = jsonencode({
        protocol    = each.value.extension.health.protocol
        port        = each.value.extension.health.port
        requestPath = each.value.extension.health.requestPath
      })
    }
  }
  dynamic extension {
    for_each = each.value.extension.monitor.enable && module.global.monitor.enable ? [1] : []
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
    for_each = each.value.extension.initialize.parameters.terminateNotification.enable ? [1] : []
    content {
      enabled = each.value.extension.initialize.parameters.terminateNotification.enable
      timeout = each.value.extension.initialize.parameters.terminateNotification.delayTimeout
    }
  }
}

output "virtualMachineScaleSets" {
  value = var.virtualMachineScaleSets
}
