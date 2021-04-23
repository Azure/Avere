// customize the secure VNET
locals {
    location = "westus"
    resource_group_name = "secure_vnet_rg"

    vnet_address_space = ["10.0.0.0/22", "10.0.4.0/25"]
    
    // GatewaySubnet
    gateway_subnet_name = "GatewaySubnet"
    gateway_subnet_address_prefix = "10.0.4.0/26"

    // cloud cache subnet
    cloud_cache_subnet_name = "cloud-cache"
    cloud_cache_subnet_address_prefix = "10.0.4.64/26"

    // render subnet
    render_subnet_name = "render-subnet"
    render_subnet_address_prefix = "10.0.0.0/22"

    // cycle cloud can live at the end of the cache subnet
    // set to empty or null if not using cycle cloud
    cycle_cloud_address = "10.0.4.126"

    // private network addresses
    private_network_prefixes = ["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"]
}

terraform {
	required_providers {
		azurerm = {
			source  = "hashicorp/azurerm"
			version = "~>2.12.0"
		}
	}
}

terraform {
  required_version = ">= 0.14.0,< 0.16.0"
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

resource "azurerm_resource_group" "render_rg" {
    name     = local.resource_group_name
    location = local.location
}

// the following is only needed if you need to ssh to the controller
resource "azurerm_network_security_group" "cache_nsg" {
    name                = "cache_nsg"
    location            = local.location
    resource_group_name = azurerm_resource_group.render_rg.name

    security_rule {
        name                       = "allowvnetin"
        priority                   = 100
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
        priority                   = 100
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
    }

    security_rule {
        name                       = "allowprivatenetworkin"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefixes    = local.private_network_prefixes
        destination_address_prefix = "VirtualNetwork"
    }

    security_rule {
        name                         = "allowprivatenetworkout"
        priority                     = 110
        direction                    = "Outbound"
        access                       = "Allow"
        protocol                     = "*"
        source_port_range            = "*"
        destination_port_range       = "*"
        source_address_prefix        = "VirtualNetwork"
        destination_address_prefixes = local.private_network_prefixes
    }

    security_rule {
        name                       = "allowazureresourcemanager"
        priority                   = 120
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "AzureResourceManager"
    }

    dynamic "security_rule" {
        for_each = local.cycle_cloud_address == null || length(local.cycle_cloud_address) == 0 ? [] : [local.cycle_cloud_address]
        content {
            name                       = "allowazurestorageforcycle"
            priority                   = 130
            direction                  = "Outbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_range     = "443"
            source_address_prefix      = local.cycle_cloud_address
            destination_address_prefix = "Storage.${local.location}"
        }
    }

    dynamic "security_rule" {
        for_each = local.cycle_cloud_address == null || length(local.cycle_cloud_address) == 0 ? [] : [local.cycle_cloud_address]
        content {
            name                       = "allowazurestorageforcycle"
            priority                   = 130
            direction                  = "Outbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_range     = "443"
            source_address_prefix      = local.cycle_cloud_address
            destination_address_prefix = "Storage.${local.location}"
        }
    }

    security_rule {
        name                       = "denyallin"
        priority                   = 200
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
        priority                   = 200
        direction                  = "Outbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_security_group" "render_nsg" {
    name                = "render_nsg"
    location            = local.location
    resource_group_name = azurerm_resource_group.render_rg.name
    
    security_rule {
        name                       = "allowvnetin"
        priority                   = 100
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
        priority                   = 100
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
    }

    security_rule {
        name                       = "allowprivatenetworkin"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefixes    = local.private_network_prefixes
        destination_address_prefix = "VirtualNetwork"
    }

    security_rule {
        name                         = "allowprivatenetworkout"
        priority                     = 110
        direction                    = "Outbound"
        access                       = "Allow"
        protocol                     = "*"
        source_port_range            = "*"
        destination_port_range       = "*"
        source_address_prefix        = "VirtualNetwork"
        destination_address_prefixes = local.private_network_prefixes
    }

    dynamic "security_rule" {
        for_each = local.cycle_cloud_address == null || length(local.cycle_cloud_address) == 0 ? [] : [local.cycle_cloud_address]
        content {
            name                       = "allowazurestorageforcycle"
            priority                   = 130
            direction                  = "Outbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_range     = "443"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "Storage.${local.location}"
        }
    }

    security_rule {
        name                       = "denyallin"
        priority                   = 200
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
        priority                   = 200
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
    address_space       = local.vnet_address_space
    location            = local.location
    resource_group_name = azurerm_resource_group.render_rg.name
}

resource "azurerm_subnet" "gateway_subnet" {
    name                 = local.gateway_subnet_name
    virtual_network_name = azurerm_virtual_network.vnet.name
    resource_group_name  = azurerm_resource_group.render_rg.name
    address_prefixes     = [local.gateway_subnet_address_prefix]
}

resource "azurerm_subnet" "cloud_cache" {
    name                 = local.cloud_cache_subnet_name
    virtual_network_name = azurerm_virtual_network.vnet.name
    resource_group_name  = azurerm_resource_group.render_rg.name
    address_prefixes     = [local.cloud_cache_subnet_address_prefix]
    service_endpoints    = local.cycle_cloud_address == null || length(local.cycle_cloud_address) == 0 ? [] : ["Microsoft.Storage"]
}

resource "azurerm_subnet_network_security_group_association" "cloud_cache" {
    subnet_id                 = azurerm_subnet.cloud_cache.id
    network_security_group_id = azurerm_network_security_group.cache_nsg.id
}

resource "azurerm_subnet" "render" {
    name                 = local.render_subnet_name
    virtual_network_name = azurerm_virtual_network.vnet.name
    resource_group_name  = azurerm_resource_group.render_rg.name
    address_prefixes     = [local.render_subnet_address_prefix]
}

resource "azurerm_subnet_network_security_group_association" "render" {
  subnet_id                 = azurerm_subnet.render.id
  network_security_group_id = azurerm_network_security_group.render_nsg.id
}
