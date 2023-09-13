regionName        = "WestUS"
resourceGroupName = "AAA"

##########################################################################################
# ExpressRoute (https://learn.microsoft.com/azure/expressroute/expressroute-introduction #
##########################################################################################

expressRoute = {
  circuit = {
    name            = "LA"
    serviceTier     = "Standard"
    serviceProvider = "Sohonet"
    peeringLocation = "Los Angeles"
    bandwidthMbps   = 50
    unlimitedData   = false
  }
}
