resource "azurerm_resource_group" "render_rg" {
    name     = var.resource_group_name
    location = var.location

    depends_on = [var.module_depends_on]
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
}

resource "azurerm_network_security_group" "no_internet_nsg" {
    name                = "no_internet_nsg"
    location            = var.location
    resource_group_name = azurerm_resource_group.render_rg.name

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
}

resource "azurerm_virtual_network" "vnet" {
    name                = "rendervnet"
    address_space       = [var.vnet_address_space]
    location            = var.location
    resource_group_name = azurerm_resource_group.render_rg.name
}

resource "azurerm_subnet" "cloud_cache" {
    name                 = var.subnet_cloud_cache_subnet_name
    virtual_network_name = azurerm_virtual_network.vnet.name
    resource_group_name  = azurerm_resource_group.render_rg.name
    address_prefixes     = [var.subnet_cloud_cache_address_prefix]
    service_endpoints    = ["Microsoft.Storage"]
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
    service_endpoints    = ["Microsoft.Storage"]
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
}

resource "azurerm_subnet_network_security_group_association" "render_clients2" {
  subnet_id                 = azurerm_subnet.render_clients2.id
  network_security_group_id = azurerm_network_security_group.no_internet_nsg.id
}