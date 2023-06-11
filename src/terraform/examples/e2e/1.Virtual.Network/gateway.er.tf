##########################################
# Virtual Network Gateway (ExpressRoute) #
##########################################

resource "azurerm_virtual_network_gateway" "express_route" {
  count               = var.networkGateway.type == "ExpressRoute" ? 1 : 0
  name                = local.computeNetworks[0].name
  resource_group_name = azurerm_resource_group.network[0].name
  location            = local.computeNetworks[0].regionName
  type                = var.networkGateway.type
  sku                 = var.expressRouteGateway.sku
  ip_configuration {
    name                 = "ipConfig"
    public_ip_address_id = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/publicIPAddresses/${local.computeNetworks[0].name}"
    subnet_id            = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetworks[0].name}/subnets/GatewaySubnet"
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.network,
    azurerm_public_ip.vnet_gateway_address1
  ]
}

resource "azurerm_virtual_network_gateway_connection" "express_route" {
  count                        = var.networkGateway.type == "ExpressRoute" && var.expressRouteGateway.connection.circuitId != "" ? 1 : 0
  name                         = local.computeNetworks[0].name
  resource_group_name          = azurerm_resource_group.network[0].name
  location                     = local.computeNetworks[0].regionName
  type                         = "ExpressRoute"
  virtual_network_gateway_id   = azurerm_virtual_network_gateway.express_route[count.index].id
  express_route_circuit_id     = var.expressRouteGateway.connection.circuitId
  express_route_gateway_bypass = var.expressRouteGateway.connection.enableFastPath
  authorization_key            = var.expressRouteGateway.connection.authorizationKey
}
