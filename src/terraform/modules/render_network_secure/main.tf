resource "azurerm_resource_group" "render_rg" {
  name     = var.resource_group_name
  location = var.location
}

// the following is only needed if you need to ssh to the controller
resource "azurerm_network_security_group" "ssh_nsg" {
  name                = "ssh_nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.render_rg.name

  dynamic "security_rule" {
    for_each = length(var.open_external_ports) > 0 ? var.open_external_sources : []
    content {
      name                       = "SSH-${security_rule.key + 120}"
      priority                   = security_rule.key + 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = var.open_external_ports
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }

  security_rule {
    name                       = "allowvnetin"
    priority                   = 500
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
    priority                   = 500
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_address_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowazurestorage"
    priority                   = 2010
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage.${var.location}"
  }

  security_rule {
    name                       = "denyallin"
    priority                   = 3000
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
    priority                   = 3000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "no_internet_nsg" {
  name                = "no_internet_nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.render_rg.name

  security_rule {
    name                       = "allowvnetin"
    priority                   = 500
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
    priority                   = 500
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allowproxy80"
    priority                   = 2000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.subnet_proxy_address_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowproxy443"
    priority                   = 2001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.subnet_proxy_address_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowazurestorage"
    priority                   = 2010
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage.${var.location}"
  }

  security_rule {
    name                       = "denyallin"
    priority                   = 3000
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
    priority                   = 3000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "rendervnet"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.render_rg.name

  tags = {
    // needed for DEVOPS testing
    SkipNRMSNSG = "12345"
  }
}

// peer the networks
////////////////////////////////////////////////////////////////
data "azurerm_virtual_network" "onprem" {
  count               = var.peer_vnet_rg == null || var.peer_vnet_rg == "" || var.peer_vnet_name == null || var.peer_vnet_name == "" ? 0 : 1
  name                = var.peer_vnet_name
  resource_group_name = var.peer_vnet_rg
}

resource "azurerm_virtual_network_peering" "peer-to-onprem" {
  count                     = var.peer_vnet_rg == null || var.peer_vnet_rg == "" || var.peer_vnet_name == null || var.peer_vnet_name == "" ? 0 : 1
  name                      = "peertoonprem"
  resource_group_name       = azurerm_virtual_network.vnet.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = data.azurerm_virtual_network.onprem[0].id

  depends_on = [
    azurerm_virtual_network.vnet,
  ]
}

resource "azurerm_virtual_network_peering" "peer-from-onprem" {
  count                     = var.peer_vnet_rg == null || var.peer_vnet_rg == "" || var.peer_vnet_name == null || var.peer_vnet_name == "" ? 0 : 1
  name                      = "peerfromonprem"
  resource_group_name       = var.peer_vnet_rg
  virtual_network_name      = var.peer_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.vnet.id

  depends_on = [
    azurerm_virtual_network.vnet,
  ]
}

// subnets
////////////////////////////////////////////////////////////////

resource "azurerm_subnet" "cloud_cache" {
  name                 = var.subnet_cloud_cache_subnet_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.render_rg.name
  address_prefixes     = [var.subnet_cloud_cache_address_prefix]
  service_endpoints    = ["Microsoft.Storage"]

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
  ]
}

resource "azurerm_subnet_network_security_group_association" "cloud_cache" {
  subnet_id                 = azurerm_subnet.cloud_cache.id
  network_security_group_id = azurerm_network_security_group.no_internet_nsg.id
}

resource "azurerm_subnet" "cloud_filers" {
  name                 = var.subnet_cloud_filers_subnet_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.render_rg.name
  address_prefixes     = [var.subnet_cloud_filers_address_prefix]

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
  ]
}

resource "azurerm_subnet_network_security_group_association" "cloud_filers" {
  subnet_id                 = azurerm_subnet.cloud_filers.id
  network_security_group_id = azurerm_network_security_group.no_internet_nsg.id
}

resource "azurerm_subnet" "jumpbox" {
  name                 = var.subnet_jumpbox_subnet_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.render_rg.name
  address_prefixes     = [var.subnet_jumpbox_address_prefix]
  # needed for the controller to add storage containers
  service_endpoints = ["Microsoft.Storage"]

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
  ]
}

resource "azurerm_subnet_network_security_group_association" "jumpbox" {
  subnet_id                 = azurerm_subnet.jumpbox.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg.id
}

resource "azurerm_subnet" "render_clients1" {
  name                 = var.subnet_render_clients1_subnet_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.render_rg.name
  address_prefixes     = [var.subnet_render_clients1_address_prefix]

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
  ]
}

// partition the render clients in groups of roughly 500 nodes (max 507, and azure takes 5 reserved)
resource "azurerm_subnet_network_security_group_association" "render_clients1" {
  subnet_id                 = azurerm_subnet.render_clients1.id
  network_security_group_id = azurerm_network_security_group.no_internet_nsg.id
}

resource "azurerm_subnet" "render_clients2" {
  name                 = var.subnet_render_clients2_subnet_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.render_rg.name
  address_prefixes     = [var.subnet_render_clients2_address_prefix]

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
  ]
}

resource "azurerm_subnet_network_security_group_association" "render_clients2" {
  subnet_id                 = azurerm_subnet.render_clients2.id
  network_security_group_id = azurerm_network_security_group.no_internet_nsg.id
}

resource "azurerm_subnet" "proxy" {
  name                 = var.subnet_proxy_subnet_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.render_rg.name
  address_prefixes     = [var.subnet_proxy_address_prefix]

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
  ]
}

resource "azurerm_subnet_network_security_group_association" "proxy" {
  subnet_id                 = azurerm_subnet.proxy.id
  network_security_group_id = azurerm_network_security_group.no_internet_nsg.id
}
