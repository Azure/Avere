resourceGroupName = "AzureArtistAnywhere.Network"

################################################################################################
# Virtual Network (https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview) #
################################################################################################

virtualNetwork = {
  name               = "Network"
  addressSpace       = ["10.0.0.0/16"]
  dnsServerAddresses = [] 
  subnets = [
    {
      name              = "Farm"
      addressSpace      = ["10.0.0.0/17"]
      serviceEndpoints  = [],
      serviceDelegation = ""
    },
    {
      name              = "Workstation"
      addressSpace      = ["10.0.128.0/18"]
      serviceEndpoints  = []
      serviceDelegation = ""
    },
    {
      name              = "Cache"
      addressSpace      = ["10.0.192.0/24"]
      serviceEndpoints  = ["Microsoft.Storage"]
      serviceDelegation = ""
    },
    {
      name              = "Storage"
      addressSpace      = ["10.0.193.0/24"]
      serviceEndpoints  = ["Microsoft.Storage"]
      serviceDelegation = ""
    },
    {
      name              = "StorageNetApp"
      addressSpace      = ["10.0.194.0/24"]
      serviceEndpoints  = []
      serviceDelegation = "Microsoft.Netapp/volumes"
    },
    {
      name              = "StorageHA"
      addressSpace      = ["10.0.195.0/29"]
      serviceEndpoints  = []
      serviceDelegation = ""
    },
    {
      name              = "GatewaySubnet"
      addressSpace      = ["10.0.255.0/24"]
      serviceEndpoints  = []
      serviceDelegation = ""
    }
  ]
}

virtualNetworkSubnetIndex = {
  farm          = 0
  workstation   = 1
  cache         = 2
  storage       = 3
  storageNetApp = 4
  storageHA     = 5
}

###########################################################################
# Private DNS (https://docs.microsoft.com/azure/dns/private-dns-overview) #
###########################################################################

virtualNetworkPrivateDns = {
  zoneName               = "artist.studio"
  enableAutoRegistration = true
}

########################################
# Hybrid Network (VPN or ExpressRoute) #
########################################

hybridNetwork = {
  type = ""
  //type = "Vpn"          // https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways
  //type = "ExpressRoute" // https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways
  address = {
    type             = "Basic"
    allocationMethod = "Dynamic"
  }
}

##############################################################################################################
# Virtual Network Gateway (VPN) (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) #
##############################################################################################################

vpnGateway = {
  sku          = "VpnGw2"
  type         = "RouteBased"
  generation   = "Generation2"
  activeActive = false
}

# Site-to-Site Local Network Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#lng)
vpnGatewayLocal = {
  fqdn              = "" // Set the fully-qualified domain name (FQDN) of your on-premises VPN gateway device
  address           = "" // OR set the public IP address of your on-prem VPN gateway device. Do not set both.
  addressSpace      = []
  bgpAsn            = 0
  bgpPeeringAddress = ""
  bgpPeerWeight     = 0
}

# Point-to-Site Client (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps)
vpnGatewayClient = {
  addressSpace    = ["10.1.0.0/24"]
  certificateName = "AzureArtistAnywhere"
  certificateData = "MIIC+zCCAeOgAwIBAgIQJ88qKp6SvoNKCcUQ3N7NJjANBgkqhkiG9w0BAQsFADAgMR4wHAYDVQQDDBVBenVyZSBBcnRpc3QgQW55d2hlcmUwHhcNMjIwMzI3MTYyMjI0WhcNMjMwMzI3MTY0MjI0WjAgMR4wHAYDVQQDDBVBenVyZSBBcnRpc3QgQW55d2hlcmUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC9LpnF4J9TD3Xuaua9cc/73He1By39484+3f3a6YbOSVF0Ah9L3xWlH8oZ1nYRs6f5XIM3sKhJqU4X5g4dRZhKN+1umy+omzUMGqdajIbNdxk38oxrhqeepAN9l2JXnYG97M8leDHN86FDHGiOqgCxhSdx/2Dxh0ibLzOM3NoFaxU2d1CMu/Xe8etPMGreHOSyh5V9oSLskjhYNu6G8//dm3RKuDf4owKXXijAgEizV1wuYIpD7CjP7DUQv3dxaQl20YGRRk59fg4tO/DpQNT/TQgwdFopez1E9ayAexeCCRnb/FcMMjgxiaecPZg52HMCdCu21CNiuC8bdFlqPkXdAgMBAAGjMTAvMA4GA1UdDwEB/wQEAwICBDAdBgNVHQ4EFgQUH7hM7fNbdfnLMpGixzQ/+dJgcrkwDQYJKoZIhvcNAQELBQADggEBAGYYfHGBgxo8WQG6dSLzbeQNYHyAE4HjJiq2S0OtouIHK8WSX7H6ysjtsXkaq/N5nAzfwh5VAaCLlcTMc0nAK/FkVEmuEJEqX8ZRcRdEPGTcus+ZhguMHYuMyytnZFVQHvJKedaWE9D1pjyXnSsUd75fc9t+RSsDqEfeLzh465O3sIeakysqQZJ8jsOEcU0kq/qwz3yA7G0DDeAoG9x/CA19CRn+SB2CW1ZknFFRRQJ3ZZRCThwVEZt4xm0r6w3QDz3ZqJRNZXiAavkG0J2l5zrUGkoEdfGasnBh6fpU6blXOUFmsPSBIMZ2RwJ/6ZuL+GQua0rUpL6NGc273RlXQL8="
}

######################################################################################################################################
# Virtual Network Gateway (ExpressRoute) (https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) #
######################################################################################################################################

expressRoute = {
  circuitId          = ""         // Expected format is "/subscriptions/[subscription_id]/resourceGroups/[resource_group_name]/providers/Microsoft.Network/expressRouteCircuits/[circuit_name]"
  gatewaySku         = "Standard" // https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways#gwsku
  connectionFastPath = false      // https://docs.microsoft.com/azure/expressroute/about-fastpath
}
