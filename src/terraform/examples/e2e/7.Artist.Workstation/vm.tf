#########################################################################
# Virtual Machines (https://learn.microsoft.com/azure/virtual-machines) #
#########################################################################

variable "virtualMachines" {
  type = list(object(
    {
      enable = bool
      name   = string
      machine = object(
        {
          size = string
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
                  fileSystemMounts = list(object(
                    {
                      enable = bool
                      mount  = string
                    }
                  ))
                  pcoipLicenseKey = string
                }
              )
            }
          )
          monitor = object(
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
  virtualMachines = [
    for virtualMachine in var.virtualMachines : merge(virtualMachine,
      {
        adminLogin = {
          userName     = virtualMachine.adminLogin.userName != "" ? virtualMachine.adminLogin.userName : try(data.azurerm_key_vault_secret.admin_username[0].value, "")
          userPassword = virtualMachine.adminLogin.userPassword != "" ? virtualMachine.adminLogin.userPassword : try(data.azurerm_key_vault_secret.admin_password[0].value, "")
          sshPublicKey = virtualMachine.adminLogin.sshPublicKey
          passwordAuth = {
            disable = virtualMachine.adminLogin.passwordAuth.disable
          }
        }
        activeDirectory = {
          enable           = virtualMachine.activeDirectory.enable
          domainName       = virtualMachine.activeDirectory.domainName
          domainServerName = virtualMachine.activeDirectory.domainServerName
          orgUnitPath      = virtualMachine.activeDirectory.orgUnitPath
          adminUsername    = virtualMachine.activeDirectory.adminUsername != "" ? virtualMachine.activeDirectory.adminUsername : try(data.azurerm_key_vault_secret.admin_username[0].value, "")
          adminPassword    = virtualMachine.activeDirectory.adminPassword != "" ? virtualMachine.activeDirectory.adminPassword : try(data.azurerm_key_vault_secret.admin_password[0].value, "")
        }
      }
    )
  ]
}

resource "azurerm_network_interface" "workstation" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.enable
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.workstation.name
  location            = azurerm_resource_group.workstation.location
  ip_configuration {
    name                          = "ipConfig"
    subnet_id                     = data.azurerm_subnet.workstation.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.trafficManager.enable ? azurerm_public_ip.workstation[each.value.name].id : null
  }
  enable_accelerated_networking = each.value.network.enableAcceleration
}

resource "azurerm_linux_virtual_machine" "workstation" {
  for_each = {
    for virtualMachine in local.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.enable && virtualMachine.operatingSystem.type == "Linux"
  }
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.workstation.name
  location                        = azurerm_resource_group.workstation.location
  size                            = each.value.machine.size
  source_image_id                 = each.value.machine.image.id
  admin_username                  = each.value.adminLogin.userName
  admin_password                  = each.value.adminLogin.userPassword
  disable_password_authentication = each.value.adminLogin.passwordAuth.disable
  network_interface_ids = [
    "${azurerm_resource_group.workstation.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
    disk_size_gb         = each.value.operatingSystem.disk.sizeGB
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
  depends_on = [
    azurerm_network_interface.workstation
  ]
}

resource "azurerm_virtual_machine_extension" "initialize_linux" {
  for_each = {
    for virtualMachine in local.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.enable && virtualMachine.extension.initialize.enable && virtualMachine.operatingSystem.type == "Linux"
  }
  name                       = "Initialize"
  type                       = "CustomScript"
  publisher                  = "Microsoft.Azure.Extensions"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.workstation.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    script = "${base64encode(
      templatefile(each.value.extension.initialize.fileName, merge(each.value.extension.initialize.parameters,
        {
          activeDirectory = each.value.activeDirectory
        }
      ))
    )}"
  })
  depends_on = [
    azurerm_linux_virtual_machine.workstation
  ]
}

resource "azurerm_virtual_machine_extension" "monitor_linux" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.enable && virtualMachine.extension.monitor.enable && virtualMachine.operatingSystem.type == "Linux" && module.global.monitor.enable
  }
  name                       = "Monitor"
  type                       = "AzureMonitorLinuxAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type_handler_version       = "1.21"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.workstation.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    workspaceId = data.azurerm_log_analytics_workspace.monitor[0].workspace_id
  })
  protected_settings = jsonencode({
    workspaceKey = data.azurerm_log_analytics_workspace.monitor[0].primary_shared_key
  })
  depends_on = [
    azurerm_linux_virtual_machine.workstation
  ]
}

resource "azurerm_windows_virtual_machine" "workstation" {
  for_each = {
    for virtualMachine in local.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.enable && virtualMachine.operatingSystem.type == "Windows"
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.workstation.name
  location            = azurerm_resource_group.workstation.location
  size                = each.value.machine.size
  source_image_id     = each.value.machine.image.id
  admin_username      = each.value.adminLogin.userName
  admin_password      = each.value.adminLogin.userPassword
  custom_data         = base64encode(templatefile("../0.Global.Foundation/functions.ps1", {}))
  network_interface_ids = [
    "${azurerm_resource_group.workstation.id}/providers/Microsoft.Network/networkInterfaces/${each.value.name}"
  ]
  os_disk {
    storage_account_type = each.value.operatingSystem.disk.storageType
    caching              = each.value.operatingSystem.disk.cachingType
    disk_size_gb         = each.value.operatingSystem.disk.sizeGB
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  depends_on = [
    azurerm_network_interface.workstation
  ]
}

resource "azurerm_virtual_machine_extension" "initialize_windows" {
  for_each = {
    for virtualMachine in local.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.enable && virtualMachine.extension.initialize.enable && virtualMachine.operatingSystem.type == "Windows"
  }
  name                       = "Initialize"
  type                       = "CustomScriptExtension"
  publisher                  = "Microsoft.Compute"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.workstation.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    commandToExecute = "PowerShell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(
      templatefile(each.value.extension.initialize.fileName, merge(each.value.extension.initialize.parameters,
        {
          activeDirectory = each.value.activeDirectory
        }
      )), "UTF-16LE"
    )}"
  })
  depends_on = [
    azurerm_windows_virtual_machine.workstation
  ]
}

resource "azurerm_virtual_machine_extension" "monitor_windows" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.enable && virtualMachine.extension.monitor.enable && virtualMachine.operatingSystem.type == "Windows" && module.global.monitor.enable
  }
  name                       = "Monitor"
  type                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type_handler_version       = "1.7"
  auto_upgrade_minor_version = true
  virtual_machine_id         = "${azurerm_resource_group.workstation.id}/providers/Microsoft.Compute/virtualMachines/${each.value.name}"
  settings = jsonencode({
    workspaceId = data.azurerm_log_analytics_workspace.monitor[0].workspace_id
  })
  protected_settings = jsonencode({
    workspaceKey = data.azurerm_log_analytics_workspace.monitor[0].primary_shared_key
  })
  depends_on = [
    azurerm_windows_virtual_machine.workstation
  ]
}

output "virtualMachines" {
  value = var.virtualMachines
}
