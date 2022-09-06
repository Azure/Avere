terraform {
  required_version = ">= 1.2.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.21.1"
    }
  }
  backend "azurerm" {
    key = "2.network"
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
  source = "../0.global"
}

variable "resourceGroupName" {
  type = string
}

variable "computeNetwork" {
  type = object(
    {
      name               = string
      regionName         = string
      addressSpace       = list(string)
      dnsServerAddresses = list(string)
      subnets = list(object(
        {
          name              = string
          addressSpace      = list(string)
          serviceEndpoints  = list(string)
          serviceDelegation = string
        }
      ))
    }
  )
}

variable "computeNetworkSubnetIndex" {
  type = object(
    {
      farm        = number
      workstation = number
      cache       = number
    }
  )
}

variable "storageNetwork" {
  type = object(
    {
      name               = string
      regionName         = string
      addressSpace       = list(string)
      dnsServerAddresses = list(string)
      subnets = list(object(
        {
          name              = string
          addressSpace      = list(string)
          serviceEndpoints  = list(string)
          serviceDelegation = string
        }
      ))
    }
  )
}

variable "storageNetworkSubnetIndex" {
  type = object(
    {
      storage1      = number
      storage2      = number
      storageNetApp = number
    }
  )
}

variable "privateDns" {
  type = object(
    {
      zoneName               = string
      enableAutoRegistration = bool
    }
  )
}

variable "hybridNetwork" {
  type = object(
    {
      type    = string
      address = object(
        {
          type             = string
          allocationMethod = string
        }
      )
    }
  )
}

variable "vpnGateway" {
  type = object(
    {
      sku                = string
      type               = string
      generation         = string
      enableBgp          = bool
      enableActiveActive = bool
    }
  )
}

variable "vpnGatewayLocal" {
  type = object(
    {
      fqdn              = string
      address           = string
      addressSpace      = list(string)
      bgpAsn            = number
      bgpPeeringAddress = string
      bgpPeerWeight     = number
    }
  )
}

variable "vpnGatewayClient" {
  type = object(
    {
      addressSpace    = list(string)
      certificateName = string
      certificateData = string
    }
  )
}

variable "expressRoute" {
  type = object(
    {
      circuitId          = string
      gatewaySku         = string
      connectionFastPath = bool
      connectionAuthKey  = string
    }
  )
}

data "azurerm_key_vault" "vault" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "gateway_connection" {
  name         = module.global.keyVaultSecretNameGatewayConnection
  key_vault_id = data.azurerm_key_vault.vault.id
}

locals {
  virtualNetwork = {
    name               = var.computeNetwork.name
    regionName         = var.computeNetwork.regionName
    addressSpace       = concat(var.computeNetwork.addressSpace, var.storageNetwork.addressSpace)
    dnsServerAddresses = concat(var.computeNetwork.dnsServerAddresses, var.storageNetwork.dnsServerAddresses)
    subnets            = concat(var.computeNetwork.subnets, [for storageNetworkSubnet in var.storageNetwork.subnets : storageNetworkSubnet if storageNetworkSubnet.name != "GatewaySubnet"])
  }
  virtualNetworks        = var.storageNetwork.name == "" ? [var.computeNetwork] : distinct(var.computeNetwork.regionName == var.storageNetwork.regionName ? [local.virtualNetwork, local.virtualNetwork] : [var.computeNetwork, var.storageNetwork])
  virtualNetworksSubnets = flatten([
    for virtualNetwork in local.virtualNetworks : [
      for virtualNetworkSubnet in virtualNetwork.subnets : merge(
        virtualNetworkSubnet,
        {regionName = virtualNetwork.regionName},
        {virtualNetworkName = virtualNetwork.name}
      )
    ]
  ])
}

resource "azurerm_resource_group" "network" {
  name     = var.resourceGroupName
  location = var.computeNetwork.regionName
}

################################################################################################
# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview) #
################################################################################################

resource "azurerm_virtual_network" "network" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  address_space       = each.value.addressSpace
  dns_servers         = each.value.dnsServerAddresses
}

resource "azurerm_subnet" "network" {
  for_each = {
    for virtualNetworksSubnet in local.virtualNetworksSubnets : "${virtualNetworksSubnet.virtualNetworkName}.${virtualNetworksSubnet.name}" => virtualNetworksSubnet
  }
  name                                          = each.value.name
  resource_group_name                           = azurerm_resource_group.network.name
  virtual_network_name                          = each.value.virtualNetworkName
  address_prefixes                              = each.value.addressSpace
  service_endpoints                             = each.value.serviceEndpoints
  private_endpoint_network_policies_enabled     = each.value.name == "GatewaySubnet"
  private_link_service_network_policies_enabled = each.value.name == "GatewaySubnet"
  dynamic "delegation" {
    for_each = each.value.serviceDelegation != "" ? [1] : []
    content {
      name = "serviceDelegation"
      service_delegation {
        name = each.value.serviceDelegation
        actions = [
          "Microsoft.Network/networkinterfaces/*",
          "Microsoft.Network/virtualNetworks/subnets/join/action"
        ]
      }
    }
  }
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_network_security_group" "network" {
  for_each = {
    for virtualNetworksSubnet in local.virtualNetworksSubnets : "${virtualNetworksSubnet.virtualNetworkName}.${virtualNetworksSubnet.name}" => virtualNetworksSubnet if virtualNetworksSubnet.name != "GatewaySubnet" && virtualNetworksSubnet.serviceDelegation == ""
  }
  name                = "${each.value.virtualNetworkName}.${each.value.name}"
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  security_rule {
    name                       = "SSH"
    priority                   = 2000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "GatewayManager"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }
  security_rule {
    name                       = "RDP"
    priority                   = 2001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "GatewayManager"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "3389"
  }
}

resource "azurerm_subnet_network_security_group_association" "network" {
  for_each = {
    for virtualNetworksSubnet in local.virtualNetworksSubnets : "${virtualNetworksSubnet.virtualNetworkName}.${virtualNetworksSubnet.name}" => virtualNetworksSubnet if virtualNetworksSubnet.name != "GatewaySubnet" && virtualNetworksSubnet.serviceDelegation == ""
  }
  subnet_id                 = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
  network_security_group_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/networkSecurityGroups/${each.value.virtualNetworkName}.${each.value.name}"
  depends_on = [
    azurerm_subnet.network,
    azurerm_network_security_group.network
  ]
}

###########################################################################
# Private DNS (https://docs.microsoft.com/azure/dns/private-dns-overview) #
###########################################################################

resource "azurerm_private_dns_zone" "network" {
  name                = var.privateDns.zoneName
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork
  }
  name                  = each.value.name
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.network.name
  virtual_network_id    = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.name}"
  registration_enabled  = var.privateDns.enableAutoRegistration
  depends_on = [
    azurerm_virtual_network.network
  ]
}

########################################
# Hybrid Network (VPN or ExpressRoute) #
########################################

resource "azurerm_public_ip" "address1" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if var.hybridNetwork.type != ""
  }
  name                = "${each.value.name}1"
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  sku                 = var.hybridNetwork.address.type
  allocation_method   = var.hybridNetwork.address.allocationMethod
}

resource "azurerm_public_ip" "address2" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if var.hybridNetwork.type == "Vpn" && var.vpnGateway.enableActiveActive
  }
  name                = "${each.value.name}2"
  resource_group_name = azurerm_resource_group.network.name
  location            = each.value.regionName
  sku                 = var.hybridNetwork.address.type
  allocation_method   = var.hybridNetwork.address.allocationMethod
}

#################################
# Virtual Network Gateway (VPN) #
#################################

resource "azurerm_virtual_network_gateway" "vpn" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if var.hybridNetwork.type == "Vpn"
  }
  name                       = each.value.name
  resource_group_name        = azurerm_resource_group.network.name
  location                   = each.value.regionName
  type                       = var.hybridNetwork.type
  sku                        = var.vpnGateway.sku
  vpn_type                   = var.vpnGateway.type
  generation                 = var.vpnGateway.generation
  enable_bgp                 = var.vpnGateway.enableBgp
  active_active              = var.vpnGateway.enableActiveActive
  ip_configuration {
    name                 = "ipConfig1"
    public_ip_address_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/publicIPAddresses/${each.value.name}1"
    subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
  }
  dynamic "ip_configuration" {
    for_each = var.vpnGateway.enableActiveActive ? [1] : []
    content {
      name                 = "ipConfig2"
      public_ip_address_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/publicIPAddresses/${each.value.name}2"
      subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
    }
  }
  dynamic "vpn_client_configuration" {
    for_each = length(var.vpnGatewayClient.addressSpace) > 0 ? [1] : []
    content {
      address_space = var.vpnGatewayClient.addressSpace
      root_certificate {
        name             = var.vpnGatewayClient.certificateName
        public_cert_data = var.vpnGatewayClient.certificateData
      }
    }
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.network,
    azurerm_public_ip.address1,
    azurerm_public_ip.address2
  ]
}

resource "azurerm_virtual_network_gateway_connection" "vnet_to_vnet_up" {
  count                           = var.hybridNetwork.type == "Vpn" ? length(local.virtualNetworks) - 1 : 0
  name                            = "${local.virtualNetworks[count.index].name}.${local.virtualNetworks[count.index + 1].name}"
  resource_group_name             = azurerm_resource_group.network.name
  location                        = local.virtualNetworks[count.index].regionName
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualNetworks[count.index].name}"
  peer_virtual_network_gateway_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualNetworks[count.index + 1].name}"
  shared_key                      = data.azurerm_key_vault_secret.gateway_connection.value
  depends_on = [
    azurerm_virtual_network_gateway.vpn
  ]
}

resource "azurerm_virtual_network_gateway_connection" "vnet_to_vnet_down" {
  count                           = var.hybridNetwork.type == "Vpn" ? length(local.virtualNetworks) - 1 : 0
  name                            = "${local.virtualNetworks[count.index + 1].name}.${local.virtualNetworks[count.index].name}"
  resource_group_name             = azurerm_resource_group.network.name
  location                        = local.virtualNetworks[count.index + 1].regionName
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualNetworks[count.index + 1].name}"
  peer_virtual_network_gateway_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualNetworks[count.index].name}"
  shared_key                      = data.azurerm_key_vault_secret.gateway_connection.value
  depends_on = [
    azurerm_virtual_network_gateway.vpn
  ]
}

resource "azurerm_local_network_gateway" "vpn" {
  count               = var.hybridNetwork.type == "Vpn" && (var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "") ? 1 : 0
  name                = var.computeNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = var.computeNetwork.regionName
  gateway_fqdn        = var.vpnGatewayLocal.address == "" ? var.vpnGatewayLocal.fqdn : null
  gateway_address     = var.vpnGatewayLocal.fqdn == "" ? var.vpnGatewayLocal.address : null
  address_space       = var.vpnGatewayLocal.addressSpace
  dynamic "bgp_settings" {
    for_each = var.vpnGatewayLocal.bgpAsn > 0 ? [1] : []
    content {
      asn                 = var.vpnGatewayLocal.bgpAsn
      bgp_peering_address = var.vpnGatewayLocal.bgpPeeringAddress
      peer_weight         = var.vpnGatewayLocal.bgpPeerWeight
    }
  }
}

resource "azurerm_virtual_network_gateway_connection" "site_to_site" {
  count                      = var.hybridNetwork.type == "Vpn" && (var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "") ? 1 : 0
  name                       = var.computeNetwork.name
  resource_group_name        = azurerm_resource_group.network.name
  location                   = var.computeNetwork.regionName
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn[count.index].id
  local_network_gateway_id   = azurerm_local_network_gateway.vpn[count.index].id
  shared_key                 = data.azurerm_key_vault_secret.gateway_connection.value
  enable_bgp                 = var.vpnGatewayLocal.bgpAsn > 0
}

##########################################
# Virtual Network Gateway (ExpressRoute) #
##########################################

resource "azurerm_virtual_network_gateway" "express_route" {
  count               = var.hybridNetwork.type == "ExpressRoute" ? 1 : 0
  name                = var.computeNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = var.computeNetwork.regionName
  type                = var.hybridNetwork.type
  sku                 = var.expressRoute.gatewaySku
  ip_configuration {
    public_ip_address_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/publicIPAddresses/${var.computeNetwork.name}1"
    subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${var.computeNetwork.name}/subnets/GatewaySubnet"
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.network,
    azurerm_public_ip.address1
  ]
}

resource "azurerm_virtual_network_gateway_connection" "express_route" {
  count                        = var.hybridNetwork.type == "ExpressRoute" && var.expressRoute.circuitId != "" ? 1 : 0
  name                         = var.computeNetwork.name
  resource_group_name          = azurerm_resource_group.network.name
  location                     = var.computeNetwork.regionName
  type                         = "ExpressRoute"
  virtual_network_gateway_id   = azurerm_virtual_network_gateway.express_route[count.index].id
  express_route_circuit_id     = var.expressRoute.circuitId
  express_route_gateway_bypass = var.expressRoute.connectionFastPath
  authorization_key            = var.expressRoute.connectionAuthKey
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "computeNetwork" {
  value = var.computeNetwork
}

output "computeNetworkSubnetIndex" {
  value = var.computeNetworkSubnetIndex
}

output "storageNetwork" {
  value = var.computeNetwork.regionName == var.storageNetwork.regionName && var.storageNetwork.name != "" ? local.virtualNetwork : var.storageNetwork
}

output "storageNetworkSubnetIndex" {
  value = var.computeNetwork.regionName == var.storageNetwork.regionName && var.storageNetwork.name != "" ? {
    storage1      = 0 + length(var.computeNetwork.subnets)
    storage2      = 1 + length(var.computeNetwork.subnets)
    storageNetApp = 2 + length(var.computeNetwork.subnets)
  } : var.storageNetworkSubnetIndex
}

output "storageEndpointSubnets" {
  value = [
    for virtualNetworksSubnet in local.virtualNetworksSubnets : virtualNetworksSubnet if contains(virtualNetworksSubnet.serviceEndpoints, "Microsoft.Storage")
  ]
}

output "privateDns" {
  value = var.privateDns
}
