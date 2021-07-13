/*
* Creates the Network infrastructure
* 1. Virtual Network and Subnets
* 2. Network Security Groups
* 3. VPN Gateway
*/

#### Versions
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
  }
  backend "azurerm" {
    key = "1.network"
  }
}

provider "azurerm" {
  features {}
}

### Variables
variable "network_rg" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "address_space" {
  type = string
}

variable "gateway_subnet_name" {
  type = string
}

variable "gateway_subnet" {
  type = string
}

variable "cache_subnet_name" {
  type = string
}

variable "cache_subnet" {
  type = string
}

variable "rendernodes_subnet_name" {
  type = string
}

variable "rendernodes_subnet" {
  type = string
}

variable "on_prem_connectivity" {
  type = string
}
locals {
  NoVpn              = "NoVpn"
  VpnVnet2VnetTunnel = "VpnVnet2Vnet"
  VpnIpsecTunnel     = "VpnIPsec"
  is_vpn_ipsec       = var.on_prem_connectivity == local.VpnIpsecTunnel
  is_vnet_to_vnet    = var.on_prem_connectivity == local.VpnVnet2VnetTunnel
  no_vpn             = !(local.is_vpn_ipsec || local.is_vnet_to_vnet)
}

variable "vpngw_generation" {
  type = string
}

variable "vpngw_sku" {
  type = string
}

variable "onprem_dns_servers" {
  type = list(string)
}

variable "use_spoof_dns_server" {
  type = bool
}

variable "spoof_dns_server" {
  type = string
}

### Resources
resource "azurerm_resource_group" "network" {
  name     = var.network_rg
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = [var.address_space]
  dns_servers         = var.use_spoof_dns_server ? concat([var.spoof_dns_server], var.onprem_dns_servers) : var.onprem_dns_servers

  tags = {
    // needed for DEVOPS testing
    SkipNRMSNSG = "12345"
  }
}

resource "azurerm_subnet" "gatewaysubnet" {
  name                 = var.gateway_subnet_name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.gateway_subnet]
}

resource "azurerm_subnet" "cache" {
  name                 = var.cache_subnet_name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.cache_subnet]
}

resource "azurerm_subnet" "rendernodes" {
  name                 = var.rendernodes_subnet_name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.rendernodes_subnet]
}

resource "azurerm_network_security_group" "cache_nsg" {
  name                = "cache_nsg"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
}

resource "azurerm_network_security_rule" "allowvnetin" {
  name                        = "allowvnetin"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.cache_nsg.name
}

resource "azurerm_network_security_rule" "denyallin" {
  name                        = "denyallin"
  priority                    = 500
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.cache_nsg.name
}

resource "azurerm_network_security_rule" "allowvnetout" {
  name                        = "allowvnetout"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.cache_nsg.name
}

resource "azurerm_network_security_rule" "denyallout" {
  name                        = "denyallout"
  priority                    = 500
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.cache_nsg.name
}

// the following is only needed if you need to ssh to the controller
resource "azurerm_network_security_group" "rendernodes_nsg" {
  name                = "rendernodes_nsg"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location

  security_rule {
    name                       = "allowvnetout"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "denyallout"
    priority                   = 500
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowvnetin"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  // this can be toggled for access to things like centos packages
  security_rule {
    name                       = "deny80"
    priority                   = 498
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  // this can be toggled for access to things like centos packages
  security_rule {
    name                       = "deny443"
    priority                   = 499
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "denyallin"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "cache" {
  subnet_id                 = azurerm_subnet.cache.id
  network_security_group_id = azurerm_network_security_group.cache_nsg.id
  depends_on = [
    resource.azurerm_network_security_rule.allowvnetin,
    resource.azurerm_network_security_rule.denyallin,
    resource.azurerm_network_security_rule.allowvnetout,
    resource.azurerm_network_security_rule.denyallout,
  ]
}

resource "azurerm_subnet_network_security_group_association" "rendernodes" {
  subnet_id                 = azurerm_subnet.rendernodes.id
  network_security_group_id = azurerm_network_security_group.rendernodes_nsg.id
}

resource "azurerm_public_ip" "cloudgwpublicip" {
  count               = local.no_vpn ? 0 : 1
  name                = "rendergwpublicip"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "cloudvpngw" {
  count               = local.no_vpn ? 0 : 1
  name                = "rendervpngw"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = var.vpngw_generation
  sku        = var.vpngw_sku
  enable_bgp = true

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.cloudgwpublicip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gatewaysubnet.id
  }

  depends_on = [
    # the Azure vpn gateway creation will lock updates to the VNET
    # complete all vnet updates first
    azurerm_subnet_network_security_group_association.cache,
    azurerm_subnet_network_security_group_association.rendernodes
  ]
}

### Outputs
output "network_rg" {
  value = azurerm_resource_group.network.name
}

output "vnet_name" {
  value = var.vnet_name
}

output "cloud_address_space" {
  value = var.address_space
}

output "cache_subnet_name" {
  value = var.cache_subnet_name
}

output "cache_nsg_name" {
  value = resource.azurerm_network_security_group.cache_nsg.name
}

output "render_subnet_name" {
  value = var.rendernodes_subnet_name
}

output "vpn_gateway_public_ip_address" {
  value = local.no_vpn ? "" : azurerm_virtual_network_gateway.cloudvpngw[0].bgp_settings[0].peering_addresses[0].tunnel_ip_addresses[0]
}

output "vpn_gateway_asn" {
  value = local.no_vpn ? "" : azurerm_virtual_network_gateway.cloudvpngw[0].bgp_settings[0].asn
}

output "vpn_gateway_bgp_address" {
  value = local.no_vpn ? "" : azurerm_virtual_network_gateway.cloudvpngw[0].bgp_settings[0].peering_addresses[0].default_addresses[0]
}

output "vpn_gateway_id" {
  value = local.no_vpn ? "" : azurerm_virtual_network_gateway.cloudvpngw[0].id
}

output "is_vpn_ipsec" {
  value = local.is_vpn_ipsec
}

output "is_vnet_to_vnet" {
  value = local.is_vnet_to_vnet
}

output "no_vpn" {
  value = local.no_vpn
}

output "onprem_dns_servers" {
  value = var.onprem_dns_servers
}

output "use_spoof_dns_server" {
  value = var.use_spoof_dns_server
}

output "spoof_dns_server" {
  value = var.spoof_dns_server
}
