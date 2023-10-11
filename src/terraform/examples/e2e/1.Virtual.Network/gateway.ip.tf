############################################################################################################################
# Public IP Address Prefix (https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/public-ip-address-prefix ) #
# Public IP Addresses      (https://learn.microsoft.com/azure/virtual-network/ip-services/public-ip-addresses)             #
############################################################################################################################

locals {
  vpnComputeGatewayName = "${local.computeNetworks[0].name}-Gateway-VPN"
  natComputeGatewayName = "${local.computeNetworks[0].name}-Gateway-NAT"
  natStorageGatewayName = "${local.storageNetwork.name}-Gateway-NAT"
}

resource "azurerm_public_ip_prefix" "vpn_gateway" {
  count               = var.vpnGateway.enable ? 1 : 0
  name                = local.vpnComputeGatewayName
  resource_group_name = local.computeNetworks[0].resourceGroupName
  location            = local.computeNetworks[0].regionName
  prefix_length       = 31
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_public_ip" "vpn_gateway_1" {
  count               = var.vpnGateway.enable ? 1 : 0
  name                = local.virtualGatewayActiveActive ? "${local.vpnComputeGatewayName}1" : local.vpnComputeGatewayName
  resource_group_name = local.computeNetworks[0].resourceGroupName
  location            = local.computeNetworks[0].regionName
  public_ip_prefix_id = azurerm_public_ip_prefix.vpn_gateway[0].id
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "vpn_gateway_2" {
  count               = var.vpnGateway.enable && local.virtualGatewayActiveActive ? 1 : 0
  name                = "${local.vpnComputeGatewayName}2"
  resource_group_name = local.computeNetworks[0].resourceGroupName
  location            = local.computeNetworks[0].regionName
  public_ip_prefix_id = azurerm_public_ip_prefix.vpn_gateway[0].id
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip_prefix" "nat_gateway_compute" {
  count               = var.computeNetwork.enableNatGateway ? 1 : 0
  name                = local.natComputeGatewayName
  resource_group_name = local.computeNetworks[0].resourceGroupName
  location            = local.computeNetworks[0].regionName
  prefix_length       = 31
}

resource "azurerm_public_ip" "nat_gateway_compute" {
  count               = var.computeNetwork.enableNatGateway ? 1 : 0
  name                = azurerm_public_ip_prefix.nat_gateway_compute[0].name
  resource_group_name = azurerm_public_ip_prefix.nat_gateway_compute[0].resource_group_name
  location            = azurerm_public_ip_prefix.nat_gateway_compute[0].location
  public_ip_prefix_id = azurerm_public_ip_prefix.nat_gateway_compute[0].id
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip_prefix" "nat_gateway_storage" {
  count               = var.storageNetwork.enableNatGateway && local.storageNetwork.enable ? 1 : 0
  name                = local.natStorageGatewayName
  resource_group_name = local.storageNetwork.resourceGroupName
  location            = local.storageNetwork.regionName
  prefix_length       = 31
}

resource "azurerm_public_ip" "nat_gateway_storage" {
  count               = var.storageNetwork.enableNatGateway && local.storageNetwork.enable ? 1 : 0
  name                = azurerm_public_ip_prefix.nat_gateway_storage[0].name
  resource_group_name = azurerm_public_ip_prefix.nat_gateway_storage[0].resource_group_name
  location            = azurerm_public_ip_prefix.nat_gateway_storage[0].location
  public_ip_prefix_id = azurerm_public_ip_prefix.nat_gateway_storage[0].id
  sku                 = "Standard"
  allocation_method   = "Static"
}
