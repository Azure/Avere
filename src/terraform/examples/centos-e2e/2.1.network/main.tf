// customize the simple VM by editing the following local variables
locals {
  // the region of the main deployment
  location = ""
  network_resource_group_name = "network_rg"

  // virtual network settings
  vnet_name               = "vnet"
  address_space           = "10.0.0.0/16"
  // DO NOT CHANGE NAME "GatewaySubnet", Azure requires it with that name
  gateway_subnet_name     = "GatewaySubnet"
  gateway_subnet          = "10.0.0.0/24"
  cache_subnet_name       = "cache"
  cache_subnet            = "10.0.1.0/24"
  rendernodes_subnet_name = "rendernodes"
  rendernodes_subnet      = "10.0.4.0/22"
}

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.56.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "network" {
  name     = local.network_resource_group_name
  location = local.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = [local.address_space]
}

resource "azurerm_subnet" "gatewaysubnet" {
  name                 = local.gateway_subnet_name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.gateway_subnet]
}

resource "azurerm_subnet" "cache" {
  name                 = local.cache_subnet_name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.cache_subnet]
}

resource "azurerm_subnet" "rendernodes" {
  name                 = local.rendernodes_subnet_name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.rendernodes_subnet]
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
    // download.averesystems.com
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
    // download.averesystems.com
    destination_address_prefix = "AzureResourceManager"
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
    name                       = "allow80"
    priority                   = 498
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureCloud"
  }

  // this can be toggled for access to things like centos packages
  security_rule {
    name                       = "allow443"
    priority                   = 499
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureCloud"
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
}

// the following is only needed if you need to ssh to the controller
resource "azurerm_network_security_group" "rendernodes_nsg" {
  name                = "rendernodes_nsg"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location

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
}

resource "azurerm_subnet_network_security_group_association" "cache" {
  subnet_id                 = azurerm_subnet.cache.id
  network_security_group_id = azurerm_network_security_group.cache_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "rendernodes" {
  subnet_id                 = azurerm_subnet.rendernodes.id
  network_security_group_id = azurerm_network_security_group.rendernodes_nsg.id
}

output "location" {
  value = local.location
}

output "vnet_resource_group" {
  value = azurerm_resource_group.network.name
}

output "gateway_subnet_id" {
  value = azurerm_subnet.gatewaysubnet.id
}

output "virtual_network_name" {
  value = local.vnet_name
}

output "cache_network_subnet_name" {
  value = local.cache_subnet_name
}

output "render_network_subnet_name" {
  value = local.rendernodes_subnet_name
}
