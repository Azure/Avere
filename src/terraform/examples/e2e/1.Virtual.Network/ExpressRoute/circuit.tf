#######################################################################################################
# ExpressRoute Circuit (https://learn.microsoft.com/azure/expressroute/expressroute-circuit-peerings) #
#######################################################################################################

variable "expressRoute" {
  type = object(
    {
      circuit = object(
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
  )
}

resource "azurerm_express_route_circuit" "render" {
  name                  = var.expressRoute.circuit.name
  resource_group_name   = azurerm_resource_group.express_route.name
  location              = azurerm_resource_group.express_route.location
  service_provider_name = var.expressRoute.circuit.serviceProvider
  peering_location      = var.expressRoute.circuit.peeringLocation
  bandwidth_in_mbps     = var.expressRoute.circuit.bandwidthMbps
  sku {
    tier   = var.expressRoute.circuit.serviceTier
    family = var.expressRoute.circuit.unlimitedData ? "UnlimitedData" : "MeteredData"
  }
}

output "serviceKey" {
  value     = azurerm_express_route_circuit.render.service_key
  sensitive = true
}

output "serviceProviderProvisioningState" {
  value = azurerm_express_route_circuit.render.service_provider_provisioning_state
}
