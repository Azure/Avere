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
      serviceEndpoints  = ["Microsoft.Storage"]
    },
    {
      name              = "Workstation"
      addressSpace      = ["10.0.128.0/18"]
      serviceDelegation = ""
      serviceEndpoints  = []
    },
    {
      name              = "Scheduler"
      addressSpace      = ["10.0.252.0/24"]
      serviceDelegation = ""
      serviceEndpoints  = []
    },
    {
      name              = "Storage"
      addressSpace      = ["10.0.253.0/24"]
      serviceDelegation = "" // "Microsoft.Netapp/volumes"
      serviceEndpoints  = ["Microsoft.Storage"]
    },
    {
      name              = "Cache"
      addressSpace      = ["10.0.254.0/24"]
      serviceDelegation = ""
      serviceEndpoints  = ["Microsoft.Storage"]
    },
    {
      name              = "GatewaySubnet"
      addressSpace      = ["10.0.255.0/24"]
      serviceDelegation = ""
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
# Private DNS - https://docs.microsoft.com/en-us/azure/dns/private-dns-overview #
################################################################################# 

privateDns = {
  zoneName = "media.studio"
}

########################################
# Hybrid Network (VPN or ExpressRoute) #
########################################

hybridNetwork = {
  type = "VPN"          // https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways
  //type = "ExpressRoute" // https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways
  address = {
    type             = "Basic"
    allocationMethod = "Dynamic"
  }
}

####################################################################################################################
# Virtual Network Gateway (VPN) - https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways #
####################################################################################################################

vpnGateway = {
  sku          = "VpnGw2"
  type         = "RouteBased"
  generation   = "Generation2"
  activeActive = false
}

# Site-to-Site Local Network Gateway - https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#lng
vpnGatewayLocal = {
  fqdn              = "" // Set the fully-qualified domain name (FQDN) of your on-premises VPN gateway device
  address           = "" // OR set the public IP address of your on-prem VPN gateway device. Do not set both.
  addressSpace      = []
  bgpAsn            = 0
  bgpPeeringAddress = ""
  bgpPeerWeight     = 0
}

# Point-to-Site Client - https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps
vpnGatewayClient = {
  addressSpace    = ["10.1.0.0/24"]
  certificateName = "MediaStudio"
  certificateData = "MIIC9TCCAd2gAwIBAgIQUoFz+AyWjZNIkwB41MzEKTANBgkqhkiG9w0BAQsFADAdMRswGQYDVQQDDBJBenVyZSBNZWRpYSBTdHVkaW8wHhcNMjEwODI5MTcwNjQzWhcNMjIwODI5MTcyNjQzWjAdMRswGQYDVQQDDBJBenVyZSBNZWRpYSBTdHVkaW8wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC6j/Ry9yXkgeb/DSkCHFPseUbJRosES8KOF+9WgUyiOcjf3d2bbBPo7y3hL2AuWr1Uja7ffnJzffXkXvUkABHetZ8TLha/ysN/gcixYORUX1ODED8GZNZyi+Bx6T3TV0d+goArQDVH2QQcwQUoFb2Xm+uz/fi6dTGcoS7v7DBrjD7h5+8jt03gXCOgndAqQ/1CHDbNQwRgPfHDuo3t3yy2DCJWqgOrPv/G6gD6HspbGNs2WlKDzu7Pj5YFWkgrpJ5hkqV3S9pitMwUPlm1uCFSsPLcdHxdtOv/6KJVz7Ua6gActZmewvnOD5qx8uq9gYhB+XuHu9IJtCyAQFeMw83pAgMBAAGjMTAvMA4GA1UdDwEB/wQEAwICBDAdBgNVHQ4EFgQU8TtxeRZG8wnQFldF5hc8zWO0EI0wDQYJKoZIhvcNAQELBQADggEBAGulDzihQffoLUAVa530D2HhgX2zAUNEC1xOUh+emLisgP2RB8ZX7jH2BSNMCkcK4SpBlFRjS31dj7Hlwa9/d4EZ4LOpy+HQwKY+IOWP6J3OCMyj2M8G/c69efiq3wAA9vzzS2VcFRCuwTmcf/DTyymc9x2jdDIed7xWZCzxk94+Up9HtvhrzxFzAuuLjpxaarbsHwP+IeAcAbMNyMM+J1RTZb3EcYzCUWOfEqxOtDUsG6bNRnVLpO9cxFvh0aU9zPdZZ0PJ7cWLi1IXsa89lq8t25ZQZhe0gYG6y9lLIAbPFZBlUA6/T8ZHaf+yGKO29WpavvdW8AiFi3xkpa8864I="
}

############################################################################################################################################
# Virtual Network Gateway (ExpressRoute) - https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways #
############################################################################################################################################

expressRoute = {
  circuitId          = ""         // Expected format is "/subscriptions/[subscription_id]/resourceGroups/[resource_group_name]/providers/Microsoft.Network/expressRouteCircuits/[circuit_name]"
  gatewaySku         = "Standard" // https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways#gwsku
  connectionFastPath = false      // https://docs.microsoft.com/en-us/azure/expressroute/about-fastpath
}
