// customize the simple VM by editing the following local variables
locals {
  // the region of the main deployment
  network_resource_group_name = "aaaaanetwork_rg"

  // virtual network settings
  vnet_name               = "vnet"
  address_space           = "10.0.0.0/16"
  gateway_subnet_name     = "GatewaySubnet"
  gateway_subnet          = "10.0.0.0/24"
  cache_subnet_name       = "cache"
  cache_subnet            = "10.1.0.0/24"
  rendernodes_subnet_name = "rendernodes"
  rendernodes_subnet      = "10.4.0.0/22"

  // paste from keyvault outputs
  location = ""
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

  // this can be toggled for access to things like centos packages
  security_rule {
    name                       = "allow80443"
    priority                   = 499
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "80,443"
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

  // this can be toggled for access to things like centos packages
  security_rule {
    name                       = "allow80443"
    priority                   = 499
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "80,443"
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
  subnet_id                 = azurerm_subnet.rendergwsubnet1.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg1.id
}

resource "azurerm_subnet_network_security_group_association" "rendernodes" {
  subnet_id                 = azurerm_subnet.rendernodes1.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg1.id
}

