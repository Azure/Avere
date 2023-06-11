#################################################
# Virtual Network Gateway (Public IP Addresses) #
#################################################

resource "azurerm_public_ip" "vnet_gateway_address1" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if var.networkGateway.type != ""
  }
  name                = local.virtualGatewayActiveActive ? "${each.value.name}1" : "${each.value.name}"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_public_ip" "vnet_gateway_address2" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if local.virtualGatewayActiveActive
  }
  name                = "${each.value.name}2"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_public_ip" "vnet_gateway_address3" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if local.virtualGatewayActiveActive && length(var.vpnGateway.pointToSiteClient.addressSpace) > 0
  }
  name                = "${each.value.name}3"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}
