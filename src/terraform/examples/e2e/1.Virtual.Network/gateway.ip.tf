############################################################################################################################
# Public IP Address Prefix (https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/public-ip-address-prefix ) #
# Public IP Addresses      (https://learn.microsoft.com/azure/virtual-network/ip-services/public-ip-addresses)             #
############################################################################################################################

resource "azurerm_public_ip_prefix" "vpn_gateway" {
  for_each = {
    for virtualNetwork in local.vpnGatewayNetworks : virtualNetwork.name => virtualNetwork if var.vpnGateway.enable && !var.existingNetwork.enable
  }
  name                = "Gateway-VPN"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  prefix_length       = 31
  depends_on = [
    azurerm_resource_group.network_regions
  ]
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_public_ip" "vpn_gateway_1" {
  for_each = {
    for virtualNetwork in local.vpnGatewayNetworks : virtualNetwork.name => virtualNetwork if var.vpnGateway.enable && !var.existingNetwork.enable
  }
  name                = var.vpnGateway.enableActiveActive ? "${azurerm_public_ip_prefix.vpn_gateway[each.value.name].name}1" : azurerm_public_ip_prefix.vpn_gateway[each.value.name].name
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  public_ip_prefix_id = azurerm_public_ip_prefix.vpn_gateway[each.value.name].id
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_resource_group.network_regions
  ]
}

resource "azurerm_public_ip" "vpn_gateway_2" {
  for_each = {
    for virtualNetwork in local.vpnGatewayNetworks : virtualNetwork.name => virtualNetwork if var.vpnGateway.enable && !var.existingNetwork.enable && var.vpnGateway.enableActiveActive
  }
  name                = "${azurerm_public_ip_prefix.vpn_gateway[each.value.name].name}2"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  public_ip_prefix_id = azurerm_public_ip_prefix.vpn_gateway[each.value.name].id
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_resource_group.network_regions
  ]
}

resource "azurerm_public_ip_prefix" "nat_gateway" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if var.natGateway.enable && !var.existingNetwork.enable
  }
  name                = "Gateway-NAT"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  prefix_length       = 31
  depends_on = [
    azurerm_resource_group.network_regions
  ]
}

resource "azurerm_public_ip" "nat_gateway" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if var.natGateway.enable && !var.existingNetwork.enable
  }
  name                = azurerm_public_ip_prefix.nat_gateway[each.value.name].name
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  public_ip_prefix_id = azurerm_public_ip_prefix.nat_gateway[each.value.name].id
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_resource_group.network_regions
  ]
}
