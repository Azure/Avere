terraform {
  required_version = ">= 1.1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0.2"
    }
  }
  backend "azurerm" {
    key = "09.monitor"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

module "global" {
  source = "../00.global"
}

variable "resourceGroupName" {
  type = string
}

variable "virtualNetwork" {
  type = object(
    {
      name              = string
      resourceGroupName = string
    }
  )
}

data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "monitor" {
  name                = module.global.monitorWorkspaceName
  resource_group_name = module.global.securityResourceGroupName
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

data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.securityResourceGroupName
    storage_account_name = module.global.securityStorageAccountName
    container_name       = module.global.terraformStorageContainerName
    key                  = "03.storage"
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

data "azurerm_private_dns_zone" "blob" {
  count               = local.blobStorageDeployed ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.terraform_remote_state.storage.outputs.resourceGroupName
}

locals {
  blobStorageDeployed  = try(contains(data.terraform_remote_state.storage.outputs.privateEndpointTypes, "blob"), false)
  blobPrivateDnsZoneId = local.blobStorageDeployed ? data.azurerm_private_dns_zone.blob[0].id : azurerm_private_dns_zone.blob[0].id
}

resource "azurerm_resource_group" "monitor" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

resource "azurerm_monitor_private_link_scope" "monitor" {
  name                = module.global.monitorWorkspaceName
  resource_group_name = azurerm_resource_group.monitor.name
}

resource "azurerm_monitor_private_link_scoped_service" "monitor" {
  name                = module.global.monitorWorkspaceName
  resource_group_name = azurerm_resource_group.monitor.name
  linked_resource_id  = data.azurerm_log_analytics_workspace.monitor.id
  scope_name          = azurerm_monitor_private_link_scope.monitor.name
}

################################################################################# 
# Private DNS (https://docs.microsoft.com/en-us/azure/dns/private-dns-overview) #
################################################################################# 

resource "azurerm_private_dns_zone" "monitor" {
  name                = "privatelink.monitor.azure.com"
  resource_group_name = azurerm_resource_group.monitor.name
}

resource "azurerm_private_dns_zone" "opinsights_oms" {
  name                = "privatelink.oms.opinsights.azure.com"
  resource_group_name = azurerm_resource_group.monitor.name
}

resource "azurerm_private_dns_zone" "opinsights_ods" {
  name                = "privatelink.ods.opinsights.azure.com"
  resource_group_name = azurerm_resource_group.monitor.name
}

resource "azurerm_private_dns_zone" "automation" {
  name                = "privatelink.agentsvc.azure-automation.net"
  resource_group_name = azurerm_resource_group.monitor.name
}

resource "azurerm_private_dns_zone" "blob" {
  count               = local.blobStorageDeployed ? 0 : 1
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.monitor.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor" {
  name                  = "monitor"
  resource_group_name   = azurerm_resource_group.monitor.name
  private_dns_zone_name = azurerm_private_dns_zone.monitor.name
  virtual_network_id    = data.azurerm_virtual_network.network.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "opinsights_oms" {
  name                  = "opinsights_oms"
  resource_group_name   = azurerm_resource_group.monitor.name
  private_dns_zone_name = azurerm_private_dns_zone.opinsights_oms.name
  virtual_network_id    = data.azurerm_virtual_network.network.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "opinsights_ods" {
  name                  = "opinsights_ods"
  resource_group_name   = azurerm_resource_group.monitor.name
  private_dns_zone_name = azurerm_private_dns_zone.opinsights_ods.name
  virtual_network_id    = data.azurerm_virtual_network.network.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "automation" {
  name                  = "automation"
  resource_group_name   = azurerm_resource_group.monitor.name
  private_dns_zone_name = azurerm_private_dns_zone.automation.name
  virtual_network_id    = data.azurerm_virtual_network.network.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  count                 = local.blobStorageDeployed ? 0 : 1
  name                  = "blob"
  resource_group_name   = azurerm_resource_group.monitor.name
  private_dns_zone_name = azurerm_private_dns_zone.blob[0].name
  virtual_network_id    = data.azurerm_virtual_network.network.id
}

########################################################################################################## 
# Monitor Private Link (https://docs.microsoft.com/en-us/azure/azure-monitor/logs/private-link-security) #
########################################################################################################## 

resource "azurerm_private_endpoint" "monitor_farm" {
  name                = "Monitor.Farm"
  resource_group_name = azurerm_resource_group.monitor.name
  location            = azurerm_resource_group.monitor.location
  subnet_id           = data.azurerm_subnet.farm.id
  private_service_connection {
    name                           = "Monitor.Farm"
    private_connection_resource_id = azurerm_monitor_private_link_scope.monitor.id
    is_manual_connection           = false
    subresource_names = [
      "azuremonitor"
    ]
  }
  private_dns_zone_group {
    name = "Monitor.Farm"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.monitor.id,
      azurerm_private_dns_zone.opinsights_oms.id,
      azurerm_private_dns_zone.opinsights_ods.id,
      azurerm_private_dns_zone.automation.id,
      local.blobPrivateDnsZoneId
    ]
  }
}

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "monitorPrivateLink" {
  value = azurerm_monitor_private_link_scoped_service.monitor
}
