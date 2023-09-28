#####################################################################################################################
# ExpressRoute Gateway (https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) #
#####################################################################################################################

variable "expressRouteGateway" {
  type = object(
    {
      enable          = bool
      name            = string
      serviceSku      = string
      networkSubnetId = string
      circuitConnection = object(
        {
          circuitId        = string
          authorizationKey = string
          enableFastPath   = bool
        }
      )
    }
  )
}

resource "azurerm_public_ip" "express_route" {
  count               = var.expressRouteGateway.enable ? 1 : 0
  name                = var.expressRouteGateway.name
  resource_group_name = azurerm_resource_group.express_route.name
  location            = azurerm_resource_group.express_route.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "express_route" {
  count               = var.expressRouteGateway.enable ? 1 : 0
  name                = var.expressRouteGateway.name
  resource_group_name = azurerm_resource_group.express_route.name
  location            = azurerm_resource_group.express_route.location
  type                = "ExpressRoute"
  sku                 = var.expressRouteGateway.serviceSku
  ip_configuration {
    name                 = "ipConfig"
    subnet_id            = var.expressRouteGateway.networkSubnetId
    public_ip_address_id = azurerm_public_ip.express_route[0].id
  }
}

resource "azurerm_virtual_network_gateway_connection" "express_route" {
  count                        = var.expressRouteGateway.enable ? 1 : 0
  name                         = var.expressRouteGateway.name
  resource_group_name          = azurerm_resource_group.express_route.name
  location                     = azurerm_resource_group.express_route.location
  type                         = "ExpressRoute"
  virtual_network_gateway_id   = azurerm_virtual_network_gateway.express_route[0].id
  express_route_circuit_id     = var.expressRouteGateway.circuitConnection.circuitId != "" ? var.expressRouteGateway.circuitConnection.circuitId : azurerm_express_route_circuit.render[0].id
  express_route_gateway_bypass = var.expressRouteGateway.circuitConnection.enableFastPath
  authorization_key            = var.expressRouteGateway.circuitConnection.authorizationKey
}
