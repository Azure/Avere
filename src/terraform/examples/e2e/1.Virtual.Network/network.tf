#################################################################################################
# Virtual Network (https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) #
#################################################################################################

variable "virtualNetworks" {
  type = list(object({
    enable       = bool
    name         = string
    regionName   = string
    addressSpace = list(string)
    dnsAddresses = list(string)
    subnets = list(object({
      name                 = string
      addressSpace         = list(string)
      serviceEndpoints     = list(string)
      serviceDelegation    = string
      denyOutboundInternet = bool
    }))
    subnetIndex = object({
      farm        = number
      workstation = number
      storage     = number
      cache       = number
    })
  }))
}

variable "existingNetwork" {
  type = object({
    enable            = bool
    name              = string
    regionName        = string
    resourceGroupName = string
  })
}

locals {
  virtualNetwork = local.virtualNetworks[0]
  virtualNetworks = [
    for virtualNetwork in var.virtualNetworks : merge(virtualNetwork, {
      id                = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${var.resourceGroupName}.${virtualNetwork.regionName}/providers/Microsoft.Network/virtualNetworks/${virtualNetwork.name}"
      key               = "${virtualNetwork.regionName}-${virtualNetwork.name}"
      resourceGroupId   = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${var.resourceGroupName}.${virtualNetwork.regionName}"
      resourceGroupName = "${var.resourceGroupName}.${virtualNetwork.regionName}"
    }) if virtualNetwork.enable
  ]
  virtualNetworksSubnets = flatten([
    for virtualNetwork in local.virtualNetworks : [
      for subnet in virtualNetwork.subnets : merge(subnet, {
        key                = "${virtualNetwork.key}-${subnet.name}"
        regionName         = virtualNetwork.regionName
        resourceGroupId    = virtualNetwork.resourceGroupId
        resourceGroupName  = virtualNetwork.resourceGroupName
        virtualNetworkId   = virtualNetwork.id
        virtualNetworkKey  = virtualNetwork.key
        virtualNetworkName = virtualNetwork.name
      })
    ]
  ])
  virtualNetworksSubnetStorage = [
    for virtualNetwork in local.virtualNetworks : merge(virtualNetwork.subnets[virtualNetwork.subnetIndex.storage], {
      key                = "${virtualNetwork.key}-${virtualNetwork.subnets[virtualNetwork.subnetIndex.storage].name}"
      regionName         = virtualNetwork.regionName
      resourceGroupId    = virtualNetwork.resourceGroupId
      resourceGroupName  = virtualNetwork.resourceGroupName
      virtualNetworkId   = virtualNetwork.id
      virtualNetworkKey  = virtualNetwork.key
      virtualNetworkName = virtualNetwork.name
    })
  ]
  virtualNetworksSubnetsSecurity = [
    for subnet in local.virtualNetworksSubnets : subnet if subnet.name != "GatewaySubnet" && subnet.name != "AzureBastionSubnet"
  ]
}

resource "azurerm_virtual_network" "studio" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.key => virtualNetwork if !var.existingNetwork.enable
  }
  name                = each.value.name
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  address_space       = each.value.addressSpace
  dns_servers         = each.value.dnsAddresses
  depends_on = [
    azurerm_resource_group.network
  ]
}

resource "azurerm_subnet" "studio" {
  for_each = {
    for subnet in local.virtualNetworksSubnets : subnet.key => subnet if !var.existingNetwork.enable
  }
  name                                          = each.value.name
  resource_group_name                           = each.value.resourceGroupName
  virtual_network_name                          = each.value.virtualNetworkName
  address_prefixes                              = each.value.addressSpace
  service_endpoints                             = each.value.serviceEndpoints
  private_endpoint_network_policies_enabled     = each.value.name == "GatewaySubnet"
  private_link_service_network_policies_enabled = each.value.name == "GatewaySubnet"
  dynamic delegation {
    for_each = each.value.serviceDelegation != "" ? [1] : []
    content {
      name = "delegation"
      service_delegation {
        name = each.value.serviceDelegation
      }
    }
  }
  depends_on = [
    azurerm_virtual_network.studio
  ]
}

resource "azurerm_network_security_group" "studio" {
  for_each = {
    for subnet in local.virtualNetworksSubnetsSecurity : subnet.key => subnet if !var.existingNetwork.enable
  }
  name                = "${each.value.virtualNetworkName}-${each.value.name}"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  security_rule {
    name                       = "AllowOutARM"
    priority                   = 3200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "AzureResourceManager"
    destination_port_range     = "*"
  }
  security_rule {
    name                       = "AllowOutStorage"
    priority                   = 3100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "Storage"
    destination_port_range     = "*"
  }
  dynamic security_rule {
    for_each = each.value.denyOutboundInternet ? [1] : []
    content {
      name                       = "DenyOutInternet"
      priority                   = 3000
      direction                  = "Outbound"
      access                     = "Deny"
      protocol                   = "*"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "Internet"
      destination_port_range     = "*"
    }
  }
  dynamic security_rule {
    for_each = each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowInPCoIP.TCP"
      priority                   = 2000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "Internet"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_ranges = [
        "443",
        "4172",
        "60433"
      ]
    }
  }
  dynamic security_rule {
    for_each = each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowInPCoIP.UDP"
      priority                   = 2100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_address_prefix      = "Internet"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "4172"
    }
  }
  dynamic security_rule {
    for_each = each.value.denyOutboundInternet && each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowOutHTTP"
      priority                   = 2000
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "Internet"
      destination_port_range     = "80"
    }
  }
  dynamic security_rule {
    for_each = each.value.denyOutboundInternet && each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowOutPCoIP.TCP"
      priority                   = 2100
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "Internet"
      destination_port_range     = "443"
    }
  }
  dynamic security_rule {
    for_each = each.value.denyOutboundInternet && each.value.name == "Workstation" ? [1] : []
    content {
      name                       = "AllowOutPCoIP.UDP"
      priority                   = 2200
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "Internet"
      destination_port_range     = "4172"
    }
  }
  depends_on = [
    azurerm_virtual_network.studio
  ]
}

resource "azurerm_subnet_network_security_group_association" "studio" {
  for_each = {
    for subnet in local.virtualNetworksSubnetsSecurity : subnet.key => subnet if !var.existingNetwork.enable
  }
  subnet_id                 = "${each.value.virtualNetworkId}/subnets/${each.value.name}"
  network_security_group_id = "${each.value.resourceGroupId}/providers/Microsoft.Network/networkSecurityGroups/${each.value.virtualNetworkName}-${each.value.name}"
  depends_on = [
    azurerm_subnet.studio,
    azurerm_network_security_group.studio
  ]
}

output "virtualNetwork" {
  value = local.virtualNetwork
}

output "virtualNetworks" {
  value = local.virtualNetworks
}

output "storageEndpointSubnets" {
  value = flatten([
    for virtualNetwork in local.virtualNetworks : [
      for subnet in virtualNetwork.subnets : {
        name               = subnet.name
        resourceGroupName  = virtualNetwork.resourceGroupName
        virtualNetworkName = virtualNetwork.name
      } if contains(subnet.serviceEndpoints, "Microsoft.Storage.Global")
    ]
  ])
}
