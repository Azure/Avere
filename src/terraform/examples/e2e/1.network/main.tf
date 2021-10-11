terraform {
  required_version = ">= 1.0.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.80.0"
    }
  }
  backend "azurerm" {
    key = "1.network"
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

variable "virtualNetwork" {
  type = object(
    {
      name               = string
      addressSpace       = list(string)
      dnsServerAddresses = list(string)
      subnets = list(
        object(
          {
            name              = string
            addressSpace      = list(string)
            serviceDelegation = string
            serviceEndpoints  = list(string)
          }
        )
      )
    }
  )
}

variable "virtualNetworkSubnetIndexFarm" {
  type = number
}

variable "virtualNetworkSubnetIndexWorkstation" {
  type = number
}

variable "virtualNetworkSubnetIndexStorage" {
  type = number
}

variable "virtualNetworkSubnetIndexCache" {
  type = number
}

variable "hybridNetworkType" {
  type    = string
  default = ""
}

variable "hybridNetworkAddressType" {
  type = string
}

variable "hybridNetworkAddressAllocationMethod" {
  type = string
}

variable "vpnGatewaySku" {
  type = string
}

variable "vpnGatewayType" {
  type = string
}

variable "vpnGatewayGeneration" {
  type = string
}

variable "vpnGatewayActiveActive" {
  type = bool
}

variable "vpnGatewayLocalFqdn" {
  type = string
}

variable "vpnGatewayLocalAddress" {
  type = string
}

variable "vpnGatewayLocalAddressSpace" {
  type = list(string)
}

variable "vpnGatewayLocalBgpAsn" {
  type = number
}

variable "vpnGatewayLocalBgpPeeringAddress" {
  type = string
}

variable "vpnGatewayLocalBgpPeerWeight" {
  type = number
}

variable "vpnGatewayClientAddressSpace" {
  type = list(string)
}

variable "vpnGatewayClientCertificateName" {
  type = string
}

variable "vpnGatewayClientCertificateData" {
  type = string
}

variable "expressRouteCircuitId" {
  type = string
}

variable "expressRouteGatewaySku" {
  type = string
}

variable "expressRouteConnectionFastPath" {
  type = bool
}

resource "azurerm_resource_group" "network" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

######################################################################################################
# Virtual Network - https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview #
######################################################################################################

resource "azurerm_virtual_network" "network" {
  name                = var.virtualNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = var.virtualNetwork.addressSpace
  dns_servers         = var.virtualNetwork.dnsServerAddresses
}

resource "azurerm_subnet" "network" {
  for_each = {
    for x in var.virtualNetwork.subnets : x.name => x
  }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = each.value.addressSpace
  service_endpoints    = each.value.serviceEndpoints
  enforce_private_link_endpoint_network_policies = each.value.name != "GatewaySubnet"
  enforce_private_link_service_network_policies  = each.value.name != "GatewaySubnet"
  dynamic "delegation" {
    for_each = each.value.serviceDelegation != "" ? [1] : [] 
    content {
      name = "serviceDelegation"
      service_delegation {
        name    = each.value.serviceDelegation
        actions = [
          "Microsoft.Network/networkinterfaces/*",
          "Microsoft.Network/virtualNetworks/subnets/join/action"
        ]
      }
    }
  }
}

resource "azurerm_network_security_group" "network" {
  for_each = {
    for x in var.virtualNetwork.subnets : x.name => x if x.name != "GatewaySubnet" && x.serviceDelegation == ""
  }
  name                = "${var.virtualNetwork.name}.${each.value.name}"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  security_rule {
    name                       = "SSH"
    priority                   = 2000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
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
    protocol                   = "TCP"
    source_address_prefix      = "GatewayManager"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "3389"
  }
}

resource "azurerm_subnet_network_security_group_association" "network" {
  for_each = {
    for x in var.virtualNetwork.subnets : x.name => x if x.name != "GatewaySubnet" && x.serviceDelegation == ""
  }
  subnet_id                 = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${var.virtualNetwork.name}/subnets/${each.value.name}"
  network_security_group_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/networkSecurityGroups/${var.virtualNetwork.name}.${each.value.name}"
  depends_on = [
    azurerm_subnet.network,
    azurerm_network_security_group.network
  ]
}

########################################
# Hybrid Network (VPN or ExpressRoute) #
########################################

resource "azurerm_public_ip" "address1" {
  count               = var.hybridNetworkType != "" ? 1 : 0
  name                = var.vpnGatewayActiveActive ? "${var.virtualNetwork.name}1" : var.virtualNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku                 = var.hybridNetworkAddressType
  allocation_method   = var.hybridNetworkAddressAllocationMethod
}

resource "azurerm_public_ip" "address2" {
  count               = var.hybridNetworkType == "VPN" && var.vpnGatewayActiveActive ? 1 : 0
  name                = "${var.virtualNetwork.name}2"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku                 = var.hybridNetworkAddressType
  allocation_method   = var.hybridNetworkAddressAllocationMethod
}

#################################
# Virtual Network Gateway (VPN) #
#################################

data "azurerm_key_vault" "vault" {
  name                = module.global.keyVaultName
  resource_group_name = module.global.securityResourceGroupName
}

data "azurerm_key_vault_secret" "gateway_connection" {
  name         = module.global.keyVaultSecretNameGatewayConnection
  key_vault_id = data.azurerm_key_vault.vault.id
}

resource "azurerm_virtual_network_gateway" "vpn" {
  count               = var.hybridNetworkType == "VPN" ? 1 : 0
  name                = var.virtualNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  type                = var.hybridNetworkType
  sku                 = var.vpnGatewaySku
  vpn_type            = var.vpnGatewayType
  generation          = var.vpnGatewayGeneration
  active_active       = var.vpnGatewayActiveActive
  enable_bgp          = true
  ip_configuration {
    name                 = "ipConfig1"
    public_ip_address_id = azurerm_public_ip.address1[count.index].id
    subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${var.virtualNetwork.name}/subnets/GatewaySubnet"
  }
  dynamic "ip_configuration" {
    for_each = var.vpnGatewayActiveActive ? [1] : [] 
    content {
      name                 = "ipConfig2"
      public_ip_address_id = azurerm_public_ip.address2[count.index].id
      subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${var.virtualNetwork.name}/subnets/GatewaySubnet"
    }
  }
  dynamic "vpn_client_configuration" {
    for_each = length(var.vpnGatewayClientAddressSpace) > 0 ? [1] : [] 
    content {
      address_space = var.vpnGatewayClientAddressSpace
      root_certificate {
        name             = var.vpnGatewayClientCertificateName
        public_cert_data = var.vpnGatewayClientCertificateData
      }
    }
  }
  depends_on = [
   azurerm_subnet_network_security_group_association.network
  ]
}

resource "azurerm_local_network_gateway" "vpn" {
  count               = var.hybridNetworkType == "VPN" && (var.vpnGatewayLocalFqdn != "" || var.vpnGatewayLocalAddress != "") ? 1 : 0
  name                = var.virtualNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  gateway_fqdn        = var.vpnGatewayLocalAddress == "" ? var.vpnGatewayLocalFqdn : null
  gateway_address     = var.vpnGatewayLocalFqdn == "" ? var.vpnGatewayLocalAddress : null
  address_space       = var.vpnGatewayLocalAddressSpace
  dynamic "bgp_settings" {
    for_each = var.vpnGatewayLocalBgpAsn > 0 ? [1] : []
    content {
      asn                 = var.vpnGatewayLocalBgpAsn
      bgp_peering_address = var.vpnGatewayLocalBgpPeeringAddress
      peer_weight         = var.vpnGatewayLocalBgpPeerWeight
    }
  }
}

resource "azurerm_virtual_network_gateway_connection" "vpn" {
  count                      = var.hybridNetworkType == "VPN" && (var.vpnGatewayLocalFqdn != "" || var.vpnGatewayLocalAddress != "") ? 1 : 0
  name                       = var.virtualNetwork.name
  resource_group_name        = azurerm_resource_group.network.name
  location                   = azurerm_resource_group.network.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn[count.index].id
  local_network_gateway_id   = azurerm_local_network_gateway.vpn[count.index].id
  shared_key                 = data.azurerm_key_vault_secret.gateway_connection.value
  enable_bgp                 = var.vpnGatewayLocalBgpAsn > 0
}

##########################################
# Virtual Network Gateway (ExpressRoute) #
##########################################

resource "azurerm_virtual_network_gateway" "express_route" {
  count               = var.hybridNetworkType == "ExpressRoute" ? 1 : 0
  name                = var.virtualNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  type                = var.hybridNetworkType
  sku                 = var.expressRouteGatewaySku
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.address1[count.index].id
    subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${var.virtualNetwork.name}/subnets/GatewaySubnet"
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.network
  ]
}

resource "azurerm_virtual_network_gateway_connection" "express_route" {
  count                        = var.hybridNetworkType == "ExpressRoute" ? 1 : 0
  name                         = var.virtualNetwork.name
  resource_group_name          = azurerm_resource_group.network.name
  location                     = azurerm_resource_group.network.location
  type                         = "ExpressRoute"
  virtual_network_gateway_id   = azurerm_virtual_network_gateway.express_route[count.index].id
  express_route_circuit_id     = var.expressRouteCircuitId
  express_route_gateway_bypass = var.expressRouteConnectionFastPath
}

output "regionName" {
  value = module.global.regionName
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "virtualNetwork" {
  value = var.virtualNetwork
}

output "virtualNetworkSubnetIndexFarm" {
  value = var.virtualNetworkSubnetIndexFarm
}

output "virtualNetworkSubnetIndexWorkstation" {
  value = var.virtualNetworkSubnetIndexWorkstation
}

output "virtualNetworkSubnetIndexStorage" {
  value = var.virtualNetworkSubnetIndexStorage
}

output "virtualNetworkSubnetIndexCache" {
  value = var.virtualNetworkSubnetIndexCache
}
