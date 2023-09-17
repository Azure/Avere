#######################################################################################################
# ExpressRoute Circuit (https://learn.microsoft.com/azure/expressroute/expressroute-circuit-peerings) #
#######################################################################################################

variable "expressRouteCircuit" {
  type = object(
    {
      name            = string
      serviceTier     = string
      serviceProvider = string
      peeringLocation = string
      bandwidthMbps   = number
      unlimitedData   = bool
    }
  )
}

resource "azurerm_express_route_circuit" "render" {
  name                  = var.expressRouteCircuit.name
  resource_group_name   = azurerm_resource_group.express_route.name
  location              = azurerm_resource_group.express_route.location
  service_provider_name = var.expressRouteCircuit.serviceProvider
  peering_location      = var.expressRouteCircuit.peeringLocation
  bandwidth_in_mbps     = var.expressRouteCircuit.bandwidthMbps
  sku {
    tier   = var.expressRouteCircuit.serviceTier
    family = var.expressRouteCircuit.unlimitedData ? "UnlimitedData" : "MeteredData"
  }
}

output "serviceKey" {
  value     = azurerm_express_route_circuit.render.service_key
  sensitive = true
}

output "serviceProviderProvisioningState" {
  value = azurerm_express_route_circuit.render.service_provider_provisioning_state
}
