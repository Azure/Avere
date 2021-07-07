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
      version = "~>2.56.0"
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

variable "vpngw_generation" {
  type = string
}

variable "vpngw_sku" {
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

// the following is only needed if you need to ssh to the controller
resource "azurerm_network_security_group" "cache_nsg" {
  name                = "cache_nsg"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location

  security_rule {
    name                   = "avere"
    priority               = 120
    direction              = "Outbound"
    access                 = "Allow"
    protocol               = "TCP"
    source_port_range      = "*"
    destination_port_range = "443"
    source_address_prefix  = "VirtualNetwork"
    // download.averesystems.com resolves to 104.45.184.87
    destination_address_prefix = "104.45.184.87"
  }

  security_rule {
    name                   = "allowazureresourcemanager"
    priority               = 121
    direction              = "Outbound"
    access                 = "Allow"
    protocol               = "TCP"
    source_port_range      = "*"
    destination_port_range = "443"
    source_address_prefix  = "VirtualNetwork"
    // Azure Resource Manager
    destination_address_prefix = "AzureResourceManager"
  }

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
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
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
    access                     = "Allow"
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
}

resource "azurerm_subnet_network_security_group_association" "rendernodes" {
  subnet_id                 = azurerm_subnet.rendernodes.id
  network_security_group_id = azurerm_network_security_group.rendernodes_nsg.id
}

resource "azurerm_public_ip" "cloudgwpublicip" {
  name                = "rendergwpublicip"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "cloudvpngw" {
  name                = "rendervpngw"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = var.vpngw_generation
  sku        = var.vpngw_sku
  enable_bgp = true

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.cloudgwpublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gatewaysubnet.id
  }
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

output "render_subnet_name" {
  value = var.rendernodes_subnet_name
}

output "vpn_gateway_public_ip_address" {
  value = azurerm_public_ip.cloudgwpublicip.ip_address
}

output "vpn_gateway_asn" {
  value = azurerm_virtual_network_gateway.cloudvpngw.bgp_settings[0].asn
}

output "vpn_gateway_bgp_addresses" {
  value = azurerm_virtual_network_gateway.cloudvpngw.bgp_settings[0].peering_addresses[0].default_addresses
}

output "vpn_gateway_id" {
  value = azurerm_virtual_network_gateway.cloudvpngw.id
}

