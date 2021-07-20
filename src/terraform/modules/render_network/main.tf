resource "azurerm_resource_group" "render_rg" {
  name     = var.resource_group_name
  location = var.location

  count = var.create_resource_group ? 1 : 0
}

resource "azurerm_network_security_group" "ssh_nsg" {
  name                = "ssh_nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

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

  dynamic "security_rule" {
    for_each = length(var.open_external_udp_ports) > 0 ? var.open_external_sources : []
    content {
      name                       = "udp-${security_rule.key + 121}"
      priority                   = security_rule.key + 121
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_port_range          = "*"
      destination_port_ranges    = var.open_external_udp_ports
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }

  depends_on = [
    azurerm_resource_group.render_rg,
  ]
}

resource "azurerm_network_security_group" "no_internet_nsg" {
  name                = "no_internet_nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  // block all inbound from lb, etc
  security_rule {
    name                       = "nointernetinbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  depends_on = [
    azurerm_resource_group.render_rg,
  ]
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_servers         = var.dns_servers

  depends_on = [
    azurerm_resource_group.render_rg,
  ]

  tags = {
    // needed for DEVOPS testing
    SkipNRMSNSG = "12345"
  }
}

////////////////////////////////////////////////////////////////
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

////////////////////////////////////////////////////////////////
// subnets
////////////////////////////////////////////////////////////////

resource "azurerm_subnet" "cloud_cache" {
  name                 = var.subnet_cloud_cache_subnet_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = var.resource_group_name
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
  resource_group_name  = var.resource_group_name
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

resource "azurerm_subnet" "cloud_filers_ha" {
  name                 = var.subnet_cloud_filers_ha_subnet_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = var.resource_group_name
  address_prefixes     = [var.subnet_cloud_filers_ha_address_prefix]

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_virtual_network_peering.peer-to-onprem,
    azurerm_virtual_network_peering.peer-from-onprem,
  ]
}

resource "azurerm_subnet_network_security_group_association" "cloud_filers_ha" {
  subnet_id                 = azurerm_subnet.cloud_filers_ha.id
  network_security_group_id = azurerm_network_security_group.no_internet_nsg.id
}

resource "azurerm_subnet" "jumpbox" {
  name                 = var.subnet_jumpbox_subnet_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = var.resource_group_name
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
  resource_group_name  = var.resource_group_name
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
  resource_group_name  = var.resource_group_name
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
