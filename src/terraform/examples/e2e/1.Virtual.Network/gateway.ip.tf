###########################################################################################################
# Public IP Addresses (https://learn.microsoft.com/azure/virtual-network/ip-services/public-ip-addresses) #
###########################################################################################################

data "azurerm_public_ip_prefix" "gateway" {
  count               = var.networkGateway.type != "" && var.networkGateway.ipPrefix.name != "" ? 1 : 0
  name                = var.networkGateway.ipPrefix.name
  resource_group_name = var.networkGateway.ipPrefix.resourceGroupName
}

data "azurerm_public_ip" "gateway_1" {
  count               = var.networkGateway.type != "" && var.networkGateway.ipAddresses[0].name != "" ? 1 : 0
  name                = var.networkGateway.ipAddresses[0].name
  resource_group_name = var.networkGateway.ipAddresses[0].resourceGroupName
}

data "azurerm_public_ip" "gateway_2" {
  count               = var.networkGateway.type != "" && var.networkGateway.ipAddresses[1].name != "" ? 1 : 0
  name                = var.networkGateway.ipAddresses[1].name
  resource_group_name = var.networkGateway.ipAddresses[1].resourceGroupName
}

resource "azurerm_public_ip" "vpn_gateway_1" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if var.networkGateway.type == "Vpn" && var.networkGateway.ipPrefix.name != ""
  }
  name                = local.virtualGatewayActiveActive ? "${each.value.name}1" : "${each.value.name}"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  public_ip_prefix_id = data.azurerm_public_ip_prefix.gateway[0].id
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_public_ip" "vpn_gateway_2" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if local.virtualGatewayActiveActive && var.networkGateway.ipPrefix.name != ""
  }
  name                = "${each.value.name}2"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  public_ip_prefix_id = data.azurerm_public_ip_prefix.gateway[0].id
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_public_ip" "express_route_gateway" {
  count               = var.networkGateway.type == "ExpressRoute" && var.networkGateway.ipPrefix.name != "" ? 1 : 0
  name                = local.virtualGatewayNetworks[0].name
  resource_group_name = local.virtualGatewayNetworks[0].resourceGroupName
  location            = local.virtualGatewayNetworks[0].regionName
  public_ip_prefix_id = data.azurerm_public_ip_prefix.gateway[0].id
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
  count               = var.storageNetwork.enableNatGateway && local.storageNetwork.name != "" ? 1 : 0
  name                = azurerm_nat_gateway.storage[0].name
  resource_group_name = local.storageNetwork.resourceGroupName
  location            = local.storageNetwork.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
}
