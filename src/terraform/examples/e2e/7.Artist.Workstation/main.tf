terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.75.0"
    }
  }
  backend "azurerm" {
    key = "7.Artist.Workstation"
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
  source = "../0.Global.Foundation/module"
}

variable "resourceGroupName" {
  type = string
}

variable "trafficManager" {
  type = object(
    {
      enable = bool
      profile = object(
        {
          name              = string
          routingMethod     = string
          enableTrafficView = bool
        }
      )
      dns = object(
        {
          name = string
          ttl  = string
        }
      )
    }
  )
}

variable "computeNetwork" {
  type = object(
    {
      enable            = bool
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
  count               = module.global.keyVault.enable ? 1 : 0
  name                = module.global.keyVault.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_key_vault_secret" "admin_username" {
  count        = module.global.keyVault.enable ? 1 : 0
  name         = module.global.keyVault.secretName.adminUsername
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_key_vault_secret" "admin_password" {
  count        = module.global.keyVault.enable ? 1 : 0
  name         = module.global.keyVault.secretName.adminPassword
  key_vault_id = data.azurerm_key_vault.studio[0].id
}

data "azurerm_log_analytics_workspace" "monitor" {
  count               = module.global.monitor.enable ? 1 : 0
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
    key                  = "2.Image.Builder"
  }
}

data "azurerm_virtual_network" "compute" {
  name                = var.computeNetwork.enable ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = var.computeNetwork.enable ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "workstation" {
  name                 = var.computeNetwork.enable ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.workstation].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

resource "azurerm_resource_group" "workstation" {
  name     = var.resourceGroupName
  location = module.global.regionNames[0]
}

###############################################################################################
# Traffic Manager (https://learn.microsoft.comazure/traffic-manager/traffic-manager-overview) #
###############################################################################################

resource "azurerm_traffic_manager_profile" "workstation" {
  count                  = var.trafficManager.enable ? 1 : 0
  name                   = var.trafficManager.profile.name
  resource_group_name    = azurerm_resource_group.workstation.name
  traffic_routing_method = var.trafficManager.profile.routingMethod
  traffic_view_enabled   = var.trafficManager.profile.enableTrafficView
  dns_config {
    relative_name = var.trafficManager.dns.name
    ttl           = var.trafficManager.dns.ttl
  }
  monitor_config {
    protocol = "HTTP"
    port     = 80
    path     = "/"
  }
}

resource "azurerm_traffic_manager_external_endpoint" "workstation" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.enable && var.trafficManager.enable
  }
  name       = each.value.name
  target     = azurerm_public_ip.workstation[each.value.name].ip_address
  profile_id = azurerm_traffic_manager_profile.workstation[0].id
  depends_on = [
    azurerm_linux_virtual_machine.workstation,
    azurerm_windows_virtual_machine.workstation
  ]
}

resource "azurerm_public_ip" "workstation" {
  for_each = {
    for virtualMachine in var.virtualMachines : virtualMachine.name => virtualMachine if virtualMachine.enable && var.trafficManager.enable
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.workstation.name
  location            = azurerm_resource_group.workstation.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

output "resourceGroupName" {
  value = azurerm_resource_group.workstation.name
}

output "trafficManager" {
  value = {
    fqdn = var.trafficManager.enable ? azurerm_traffic_manager_profile.workstation[0].fqdn : ""
  }
}
