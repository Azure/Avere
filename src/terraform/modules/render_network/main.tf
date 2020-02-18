provider "azurerm" {
    version = "~>1.43.0"
}

resource "azurerm_resource_group" "render_rg" {
    name     = var.resource_group_name
    location = var.location
}

// the following is only needed if you need to ssh to the controller
resource "azurerm_network_security_group" "ssh_nsg" {
    name                = "ssh_nsg"
    location            = var.location
    resource_group_name = azurerm_resource_group.render_rg.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_security_group" "no_internet_nsg" {
    name                = "no_internet_nsg"
    location            = var.location
    resource_group_name = azurerm_resource_group.render_rg.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 4000
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "Internet"
        destination_address_prefix = "*"
    }
}

resource "azurerm_virtual_network" "vnet" {
    name                = "rendervnet"
    address_space       = [var.vnet_address_space]
    location            = var.location
    resource_group_name = azurerm_resource_group.render_rg.name

    // this subnet holds the cloud cache, there should be one cloud cache per subnet
    subnet {
        name           = var.subnet_cloud_cache_subnet_name
        address_prefix = var.subnet_cloud_cache_address_prefix
        security_group = azurerm_network_security_group.ssh_nsg.id
    }

    // this subnet holds the cloud filers
    subnet {
        name           = var.subnet_cloud_filers_subnet_name
        address_prefix = var.subnet_cloud_filers_address_prefix
        security_group = azurerm_network_security_group.no_internet_nsg.id
    }

    // partition the render clients in groups of roughly 500 nodes (max 507, and azure takes 5 reserved)
    subnet {
        name           = var.subnet_render_clients1_subnet_name
        address_prefix = var.subnet_render_clients1_address_prefix
        security_group = azurerm_network_security_group.no_internet_nsg.id
    }

    subnet {
        name           = var.subnet_render_clients2_subnet_name
        address_prefix = var.subnet_render_clients2_address_prefix
        security_group = azurerm_network_security_group.no_internet_nsg.id
    }
}
