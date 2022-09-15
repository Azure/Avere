resourceGroupName = "ArtistAnywhere.Network"

################################################################################################
# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview) #
################################################################################################

computeNetwork = {
  name               = "Compute"
  regionName         = "SouthCentralUS"
  addressSpace       = ["10.1.0.0/16"]
  dnsServerAddresses = []
  subnets = [
    {
      name              = "Farm"
      addressSpace      = ["10.1.0.0/17"]
      serviceEndpoints  = ["Microsoft.Storage"],
      serviceDelegation = ""
    },
    {
      name              = "Workstation"
      addressSpace      = ["10.1.128.0/18"]
      serviceEndpoints  = ["Microsoft.Storage"],
      serviceDelegation = ""
    },
    {
      name              = "Cache"
      addressSpace      = ["10.1.192.0/24"]
      serviceEndpoints  = ["Microsoft.Storage"]
      serviceDelegation = ""
    },
    {
      name              = "GatewaySubnet"
      addressSpace      = ["10.1.255.0/24"]
      serviceEndpoints  = []
      serviceDelegation = ""
    }
  ]
}

computeNetworkSubnetIndex = {
  farm        = 0
  workstation = 1
  cache       = 2
}

storageNetwork = {
  name               = "Storage" # Set name to "" to skip storage network deployment
  regionName         = "SouthCentralUS"
  addressSpace       = ["10.0.0.0/16"]
  dnsServerAddresses = []
  subnets = [
    {
      name              = "Primary"
      addressSpace      = ["10.0.0.0/24"]
      serviceEndpoints  = ["Microsoft.Storage"]
      serviceDelegation = ""
    },
    {
      name              = "Secondary"
      addressSpace      = ["10.0.1.0/24"]
      serviceEndpoints  = ["Microsoft.Storage"]
      serviceDelegation = ""
    },
    {
      name              = "NetApp"
      addressSpace      = ["10.0.2.0/24"]
      serviceEndpoints  = []
      serviceDelegation = "Microsoft.Netapp/volumes"
    }
  ]
}

storageNetworkSubnetIndex = {
  primary   = 0
  secondary = 1
  netApp    = 2
}

networkPeering = {
  enabled                     = true
  allowRemoteNetworkAccess    = true
  allowRemoteForwardedTraffic = false
  allowNetworkGatewayTransit  = false
}

###########################################################################
# Private DNS (https://docs.microsoft.com/azure/dns/private-dns-overview) #
###########################################################################

privateDns = {
  zoneName               = "artist.studio"
  enableAutoRegistration = true
}

###########################
# Virtual Network Gateway #
###########################

networkGateway = {
  type = ""
  //type = "Vpn"          # https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways
  //type = "ExpressRoute" # https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways
  address = {
    type             = "Standard"
    allocationMethod = "Static"
  }
}

##############################################################################################################
# Virtual Network Gateway (VPN) (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) #
##############################################################################################################

vpnGateway = {
  sku                = "VpnGw2"
  type               = "RouteBased"
  generation         = "Generation2"
  enableBgp          = false
  enableActiveActive = false
  pointToSiteClient = { # https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal
    addressSpace    = []
    certificateName = ""
    certificateData = ""
  }
}

#########################################################################################################################
# Local Network Gateway (VPN) (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#lng) #
#########################################################################################################################

vpnGatewayLocal = {
  fqdn         = "" # Set the fully-qualified domain name (FQDN) of your on-premises VPN gateway device
  address      = "" # OR set the public IP address of your on-prem VPN gateway device. Do not set both.
  addressSpace = []
  bgp = {
    enabled        = false
    asn            = 0
    peerWeight     = 0
    peeringAddress = ""
  }
}

######################################################################################################################################
# Virtual Network Gateway (ExpressRoute) (https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) #
######################################################################################################################################

expressRouteGateway = {
  sku = "" # https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways#gwsku
  connection = {
    circuitId        = ""    # Expected format is "/subscriptions/[subscription_id]/resourceGroups/[resource_group_name]/providers/Microsoft.Network/expressRouteCircuits/[circuit_name]"
    authorizationKey = ""
    enableFastPath   = false # https://docs.microsoft.com/azure/expressroute/about-fastpath
  }
}
