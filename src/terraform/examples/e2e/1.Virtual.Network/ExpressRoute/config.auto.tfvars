##########################################################################################
# ExpressRoute (https://learn.microsoft.com/azure/expressroute/expressroute-introduction #
##########################################################################################

regionName        = "WestUS3"
resourceGroupName = "ArtistAnywhere.Network"

#######################################################################################################
# ExpressRoute Circuit (https://learn.microsoft.com/azure/expressroute/expressroute-circuit-peerings) #
#######################################################################################################

expressRouteCircuit = {
  enable          = false
  name            = ""
  serviceTier     = "Standard" # https://learn.microsoft.com/azure/expressroute/plan-manage-cost#local-vs-standard-vs-premium
  serviceProvider = ""
  peeringLocation = ""
  bandwidthMbps   = 50
  unlimitedData   = false
}

#####################################################################################################################
# ExpressRoute Gateway (https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) #
#####################################################################################################################

expressRouteGateway = {
  enable          = false
  name            = ""
  serviceSku      = "Standard" # https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways#gwsku
  networkSubnetId = ""
  circuitConnection = {
    circuitId        = ""
    authorizationKey = ""
    enableFastPath   = false # https://learn.microsoft.com/azure/expressroute/about-fastpath
  }
}
