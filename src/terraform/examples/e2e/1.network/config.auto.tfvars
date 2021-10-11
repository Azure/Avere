resourceGroupName = "AzureRender.Network"

######################################################################################################
# Virtual Network - https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview #
######################################################################################################

virtualNetwork = {
  name               = "Network"
  addressSpace       = ["10.0.0.0/16"]
  dnsServerAddresses = [] 
  subnets = [
    {
      name              = "Farm"
      addressSpace      = ["10.0.0.0/17"]
      serviceDelegation = ""
      serviceEndpoints  = []
    },
    {
      name              = "Workstation"
      addressSpace      = ["10.0.128.0/18"]
      serviceDelegation = ""
      serviceEndpoints  = []
    },
    {
      name              = "Storage"
      addressSpace      = ["10.0.253.0/24"]
      serviceDelegation = "Microsoft.Netapp/volumes"
      serviceEndpoints  = [] // ["Microsoft.Storage"]
    },
    {
      name              = "Cache"
      addressSpace      = ["10.0.254.0/24"]
      serviceDelegation = ""
      serviceEndpoints  = [] // ["Microsoft.Storage"]
    },
    {
      name              = "GatewaySubnet"
      addressSpace      = ["10.0.255.0/24"]
      serviceDelegation = ""
      serviceEndpoints  = []
    }
  ]
}

virtualNetworkSubnetIndexFarm        = 0
virtualNetworkSubnetIndexWorkstation = 1
virtualNetworkSubnetIndexStorage     = 2
virtualNetworkSubnetIndexCache       = 3

########################################
# Hybrid Network (VPN or ExpressRoute) #
########################################

hybridNetworkType = "VPN"          // https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways
//hybridNetworkType = "ExpressRoute" // https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways

# Public IP Address - https://docs.microsoft.com/en-us/azure/virtual-network/public-ip-addresses
hybridNetworkAddressType             = "Basic"
hybridNetworkAddressAllocationMethod = "Dynamic"

####################################################################################################################
# Virtual Network Gateway (VPN) - https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways #
####################################################################################################################

vpnGatewaySku          = "VpnGw2"
vpnGatewayType         = "RouteBased"
vpnGatewayGeneration   = "Generation2"
vpnGatewayActiveActive = false

# Site-to-Site Local Network Gateway - https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#lng
vpnGatewayLocalFqdn              = "" // Set the fully-qualified domain name (FQDN) of your on-premises VPN gateway device
vpnGatewayLocalAddress           = "" // OR set the public IP address of your on-prem VPN gateway device. Do not set both.
vpnGatewayLocalAddressSpace      = []
vpnGatewayLocalBgpAsn            = 0
vpnGatewayLocalBgpPeeringAddress = ""
vpnGatewayLocalBgpPeerWeight     = 0

# Point-to-Site Client - https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps
vpnGatewayClientAddressSpace    = []
vpnGatewayClientCertificateName = ""
vpnGatewayClientCertificateData = ""

############################################################################################################################################
# Virtual Network Gateway (ExpressRoute) - https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways #
############################################################################################################################################

# ExpressRoute Circuit - https://docs.microsoft.com/en-us/azure/expressroute/expressroute-circuit-peerings#circuits
expressRouteCircuitId = "" // Expected format is "/subscriptions/[subscription_id]/resourceGroups/[resource_group_name]/providers/Microsoft.Network/expressRouteCircuits/[circuit_name]"

expressRouteGatewaySku         = "Standard" // https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways#gwsku
expressRouteConnectionFastPath = false      // https://docs.microsoft.com/en-us/azure/expressroute/about-fastpath
