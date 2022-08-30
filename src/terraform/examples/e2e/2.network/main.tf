terraform {
  required_version = ">= 1.2.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.20.0"
    }
  }
  backend "azurerm" {
    key = "2.network"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "global" {
  source = "../0.global"
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
            serviceEndpoints  = list(string)
            serviceDelegation = string
          }
        )
      )
    }
  )
}

variable "virtualNetworkSubnetIndex" {
  type = object(
    {
      farm          = number
      workstation   = number
      cache         = number
      storage       = number
      storageNetApp = number
      storageHA     = number
    }
  )
}

variable "virtualNetworkPrivateDns" {
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
      type = string
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
      sku          = string
      type         = string
      generation   = string
      activeActive = bool
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
    }
  )
}

resource "azurerm_resource_group" "network" {
  name     = var.resourceGroupName
  location = module.global.regionName
}

################################################################################################
# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview) #
################################################################################################

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
  name                                          = each.value.name
  resource_group_name                           = azurerm_resource_group.network.name
  virtual_network_name                          = azurerm_virtual_network.network.name
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
    for x in var.virtualNetwork.subnets : x.name => x if x.name != "GatewaySubnet" && x.serviceDelegation == ""
  }
  subnet_id                 = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${var.virtualNetwork.name}/subnets/${each.value.name}"
  network_security_group_id = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/networkSecurityGroups/${var.virtualNetwork.name}.${each.value.name}"
  depends_on = [
    azurerm_subnet.network,
    azurerm_network_security_group.network
  ]
}

###########################################################################
# Private DNS (https://docs.microsoft.com/azure/dns/private-dns-overview) #
###########################################################################

resource "azurerm_private_dns_zone" "network" {
  count               = var.virtualNetworkPrivateDns.zoneName != "" ? 1 : 0
  name                = var.virtualNetworkPrivateDns.zoneName
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network" {
  name                  = var.virtualNetwork.name
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.network[0].name
  virtual_network_id    = azurerm_virtual_network.network.id
  registration_enabled  = var.virtualNetworkPrivateDns.enableAutoRegistration
}

########################################
# Hybrid Network (VPN or ExpressRoute) #
########################################

resource "azurerm_public_ip" "address1" {
  count               = var.hybridNetwork.type != "" ? 1 : 0
  name                = var.vpnGateway.activeActive ? "${var.virtualNetwork.name}1" : var.virtualNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku                 = var.hybridNetwork.address.type
  allocation_method   = var.hybridNetwork.address.allocationMethod
}

resource "azurerm_public_ip" "address2" {
  count               = var.hybridNetwork.type == "Vpn" && var.vpnGateway.activeActive ? 1 : 0
  name                = "${var.virtualNetwork.name}2"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku                 = var.hybridNetwork.address.type
  allocation_method   = var.hybridNetwork.address.allocationMethod
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

data "azurerm_log_analytics_workspace" "monitor" {
  name                = module.global.monitorWorkspaceName
  resource_group_name = module.global.securityResourceGroupName
}

resource "azurerm_virtual_network_gateway" "vpn" {
  count               = var.hybridNetwork.type == "Vpn" ? 1 : 0
  name                = var.virtualNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  type                = var.hybridNetwork.type
  sku                 = var.vpnGateway.sku
  vpn_type            = var.vpnGateway.type
  generation          = var.vpnGateway.generation
  active_active       = var.vpnGateway.activeActive
  enable_bgp          = true
  ip_configuration {
    name                 = "ipConfig1"
    public_ip_address_id = azurerm_public_ip.address1[count.index].id
    subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${var.virtualNetwork.name}/subnets/GatewaySubnet"
  }
  dynamic "ip_configuration" {
    for_each = var.vpnGateway.activeActive ? [1] : []
    content {
      name                 = "ipConfig2"
      public_ip_address_id = azurerm_public_ip.address2[count.index].id
      subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${var.virtualNetwork.name}/subnets/GatewaySubnet"
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
    azurerm_subnet_network_security_group_association.network
  ]
}

resource "azurerm_local_network_gateway" "vpn" {
  count               = var.hybridNetwork.type == "Vpn" && (var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "") ? 1 : 0
  name                = var.virtualNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
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

resource "azurerm_virtual_network_gateway_connection" "vpn" {
  count                      = var.hybridNetwork.type == "Vpn" && (var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "") ? 1 : 0
  name                       = var.virtualNetwork.name
  resource_group_name        = azurerm_resource_group.network.name
  location                   = azurerm_resource_group.network.location
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
  name                = var.virtualNetwork.name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  type                = var.hybridNetwork.type
  sku                 = var.expressRoute.gatewaySku
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.address1[count.index].id
    subnet_id            = "${azurerm_resource_group.network.id}/providers/Microsoft.Network/virtualNetworks/${var.virtualNetwork.name}/subnets/GatewaySubnet"
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.network
  ]
}

resource "azurerm_virtual_network_gateway_connection" "express_route" {
  count                        = var.hybridNetwork.type == "ExpressRoute" ? 1 : 0
  name                         = var.virtualNetwork.name
  resource_group_name          = azurerm_resource_group.network.name
  location                     = azurerm_resource_group.network.location
  type                         = "ExpressRoute"
  virtual_network_gateway_id   = azurerm_virtual_network_gateway.express_route[count.index].id
  express_route_circuit_id     = var.expressRoute.circuitId
  express_route_gateway_bypass = var.expressRoute.connectionFastPath
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

output "virtualNetworkSubnetIndex" {
  value = var.virtualNetworkSubnetIndex
}

output "virtualNetworkPrivateDns" {
  value = var.virtualNetworkPrivateDns
}
