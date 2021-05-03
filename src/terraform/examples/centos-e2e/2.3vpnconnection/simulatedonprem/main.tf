locals {
  # paste from key vault tf output
  key_vault_id = ""

  vpngw_generation = "Generation1" // generation and sku defined in https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark
  vpngw_sku        = "VpnGw2"

  location            = ""
  gateway_subnet_id   = ""
  vnet_resource_group = ""

  onprem_location       = ""
  onprem_resource_group = ""
  onprem_vpn_gateway_id = ""
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

data "azurerm_key_vault_secret" "vpngatewaykey" {
  name         = "vpngatewaykey"
  key_vault_id = local.key_vault_id
}

resource "azurerm_public_ip" "cloudgwpublicip" {
  name                = "rendergwpublicip"
  location            = local.location
  resource_group_name = local.vnet_resource_group

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "cloudvpngw" {
  name                = "rendervpngw"
  location            = local.location
  resource_group_name = local.vnet_resource_group

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = local.vpngw_generation
  sku        = local.vpngw_sku

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.cloudgwpublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = local.gateway_subnet_id
  }
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_cloud" {
  name                = "onprem_to_cloud"
  location            = local.onprem_location
  resource_group_name = local.onprem_resource_group

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = local.onprem_vpn_gateway_id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.cloudvpngw.id

  shared_key = data.azurerm_key_vault_secret.vpngatewaykey.value
}

resource "azurerm_virtual_network_gateway_connection" "cloud_to_onprem" {
  name                = "cloud_to_onprem"
  location            = local.location
  resource_group_name = local.vnet_resource_group

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.cloudvpngw.id
  peer_virtual_network_gateway_id = local.onprem_vpn_gateway_id

  shared_key = data.azurerm_key_vault_secret.vpngatewaykey.value
}
