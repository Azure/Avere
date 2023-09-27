############################################################################################################################
# Public IP Address Prefix (https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/public-ip-address-prefix ) #
# Public IP Addresses      (https://learn.microsoft.com/azure/virtual-network/ip-services/public-ip-addresses)             #
############################################################################################################################

locals {
  computeNetworkName = local.computeNetworks[0].name
}

resource "azurerm_public_ip_prefix" "gateway" {
  count               = var.vpnGateway.enable ? 1 : 0
  name                = local.computeNetworkName
  resource_group_name = azurerm_resource_group.network[0].name
  location            = azurerm_resource_group.network[0].location
  prefix_length       = 31
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_public_ip" "vpn_gateway_1" {
  count               = var.vpnGateway.enable ? 1 : 0
  name                = local.virtualGatewayActiveActive ? "${local.computeNetworkName}1" : local.computeNetworkName
  resource_group_name = azurerm_resource_group.network[0].name
  location            = azurerm_resource_group.network[0].location
  public_ip_prefix_id = azurerm_public_ip_prefix.gateway[0].id
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_public_ip" "vpn_gateway_2" {
  count               = var.vpnGateway.enable && local.virtualGatewayActiveActive ? 1 : 0
  name                = "${local.computeNetworkName}2"
  resource_group_name = azurerm_resource_group.network[0].name
  location            = azurerm_resource_group.network[0].location
  public_ip_prefix_id = azurerm_public_ip_prefix.gateway[0].id
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_public_ip" "nat_gateway_compute" {
  count               = var.computeNetwork.enableNatGateway ? 1 : 0
  name                = azurerm_nat_gateway.compute[0].name
  resource_group_name = local.computeNetworks[0].resourceGroupName
  location            = local.computeNetworks[0].regionName
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "nat_gateway_storage" {
  count               = var.storageNetwork.enableNatGateway && local.storageNetwork.enable ? 1 : 0
  name                = azurerm_nat_gateway.storage[0].name
  resource_group_name = local.storageNetwork.resourceGroupName
  location            = local.storageNetwork.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
}
