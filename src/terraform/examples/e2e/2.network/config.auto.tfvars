resourceGroupName = "ArtistAnywhere.Network"

######################################################################################################
# Virtual Network (https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) #
######################################################################################################

virtualNetwork = {
  name               = "Network"
  addressSpace       = ["10.0.0.0/16"]
  dnsServerAddresses = [] 
  subnets = [
    {
      name              = "Farm"
      addressSpace      = ["10.0.0.0/17"]
      serviceEndpoints  = []
    },
    {
      name              = "Workstation"
      addressSpace      = ["10.0.128.0/18"]
      serviceEndpoints  = []
    },
    {
      name              = "Scheduler"
      addressSpace      = ["10.0.252.0/24"]
      serviceEndpoints  = []
    },
    {
      name              = "Storage"
      addressSpace      = ["10.0.253.0/24"]
      serviceEndpoints  = ["Microsoft.Storage"]
    },
    {
      name              = "Cache"
      addressSpace      = ["10.0.254.0/24"]
      serviceEndpoints  = ["Microsoft.Storage"]
    },
    {
      name              = "GatewaySubnet"
      addressSpace      = ["10.0.255.0/24"]
      serviceEndpoints  = []
    }
  ]
}

virtualNetworkSubnetIndex = {
  farm        = 0
  workstation = 1
  scheduler   = 2
  storage     = 3
  cache       = 4
}

#################################################################################
# Private DNS (https://docs.microsoft.com/en-us/azure/dns/private-dns-overview) #
#################################################################################

virtualNetworkPrivateDns = {
  zoneName               = "artist.studio"
  enableAutoRegistration = true
}

########################################
# Hybrid Network (VPN or ExpressRoute) #
########################################

hybridNetwork = {
  type = ""
  //type = "Vpn"          // https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways
  //type = "ExpressRoute" // https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways
  address = {
    type             = "Basic"
    allocationMethod = "Dynamic"
  }
}

####################################################################################################################
# Virtual Network Gateway (VPN) (https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) #
####################################################################################################################

vpnGateway = {
  sku          = "VpnGw2"
  type         = "RouteBased"
  generation   = "Generation2"
  activeActive = false
}

# Site-to-Site Local Network Gateway (https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#lng)
vpnGatewayLocal = {
  fqdn              = "" // Set the fully-qualified domain name (FQDN) of your on-premises VPN gateway device
  address           = "" // OR set the public IP address of your on-prem VPN gateway device. Do not set both.
  addressSpace      = []
  bgpAsn            = 0
  bgpPeeringAddress = ""
  bgpPeerWeight     = 0
}

# Point-to-Site Client (https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps)
vpnGatewayClient = {
  addressSpace    = []
  certificateName = ""
  certificateData = ""
}

############################################################################################################################################
# Virtual Network Gateway (ExpressRoute) (https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways) #
############################################################################################################################################

expressRoute = {
  circuitId          = ""         // Expected format is "/subscriptions/[subscription_id]/resourceGroups/[resource_group_name]/providers/Microsoft.Network/expressRouteCircuits/[circuit_name]"
  gatewaySku         = "Standard" // https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways#gwsku
  connectionFastPath = false      // https://docs.microsoft.com/en-us/azure/expressroute/about-fastpath
}
