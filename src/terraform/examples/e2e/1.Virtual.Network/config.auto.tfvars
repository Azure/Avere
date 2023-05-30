resourceGroupName = "ArtistAnywhere.Network" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

#################################################################################################
# Virtual Network (https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) #
#################################################################################################

computeNetwork = {
  name       = "Studio"
  regionName = "" # Optional region override
  addressSpace = [
    "10.1.0.0/16"
  ]
  dnsIpAddresses = [
  ]
  subnets = [
    {
      name = "Farm"
      addressSpace = [
        "10.1.0.0/17"
      ]
      serviceEndpoints = [
        "Microsoft.Storage",
        "Microsoft.CognitiveServices",
        "Microsoft.ContainerRegistry"
      ]
      serviceDelegation    = ""
      denyOutboundInternet = false
    },
    {
      name = "Workstation"
      addressSpace = [
        "10.1.128.0/18"
      ]
      serviceEndpoints = [
        "Microsoft.Storage"
      ]
      serviceDelegation    = ""
      denyOutboundInternet = false
    },
    {
      name = "Storage"
      addressSpace = [
        "10.1.192.0/24"
      ]
      serviceEndpoints = [
        "Microsoft.Storage"
      ]
      serviceDelegation    = ""
      denyOutboundInternet = false
    },
    {
      name = "Cache"
      addressSpace = [
        "10.1.193.0/24"
      ]
      serviceEndpoints = [
        "Microsoft.Storage"
      ]
      serviceDelegation    = ""
      denyOutboundInternet = false
    },
    {
      name = "GatewaySubnet"
      addressSpace = [
        "10.1.255.0/26"
      ]
      serviceEndpoints = [
      ]
      serviceDelegation    = ""
      denyOutboundInternet = false
    },
    {
      name = "AzureBastionSubnet"
      addressSpace = [
        "10.1.255.64/26"
      ]
      serviceEndpoints = [
      ]
      serviceDelegation    = ""
      denyOutboundInternet = false
    }
  ]
  subnetIndex = { # Make sure each index is in sync with corresponding subnet
    farm        = 0
    workstation = 1
    storage     = 2
    cache       = 3
  }
}

storageNetwork = {
  name       = "" # Set to "" to skip storage network deployment
  regionName = "" # Optional region override
  addressSpace = [
    "10.0.0.0/16"
  ]
  dnsIpAddresses = [
  ]
  subnets = [
    {
      name = "Primary"
      addressSpace = [
        "10.0.0.0/24"
      ]
      serviceEndpoints = [
        "Microsoft.Storage"
      ]
      serviceDelegation    = ""
      denyOutboundInternet = false
    },
    {
      name = "Secondary"
      addressSpace = [
        "10.0.1.0/24"
      ]
      serviceEndpoints = [
        "Microsoft.Storage"
      ]
      serviceDelegation    = ""
      denyOutboundInternet = false
    },
    {
      name = "NetAppFiles"
      addressSpace = [
        "10.0.2.0/24"
      ]
      serviceEndpoints = [
      ]
      serviceDelegation    = "Microsoft.Netapp/volumes"
      denyOutboundInternet = false
    }
  ]
  subnetIndex = { # Make sure each index is in sync with corresponding subnet
    primary     = 0
    secondary   = 1
    netAppFiles = 2
  }
}

################################################################################################################
# Virtual Network Peering (https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview) #
################################################################################################################

networkPeering = {
  enable                      = true
  allowRemoteNetworkAccess    = true
  allowRemoteForwardedTraffic = true
}

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

privateDns = {
  zoneName               = "artist.studio"
  enableAutoRegistration = true
}

########################################################################
# Bastion (https://learn.microsoft.com/azure/bastion/bastion-overview) #
########################################################################

bastion = {
  enable              = true
  sku                 = "Standard"
  scaleUnitCount      = 2
  enableFileCopy      = true
  enableCopyPaste     = true
  enableIpConnect     = true
  enableTunneling     = true
  enableShareableLink = false
}

##########################################################################################################################
# Network Address Translation (NAT) Gateway (https://learn.microsoft.com/azure/virtual-network/nat-gateway/nat-overview) #
##########################################################################################################################

natGateway = {
  enable = false
}

###########################
# Virtual Network Gateway #
###########################

networkGateway = {
  type = ""
  //type = "Vpn"          # https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways
  //type = "ExpressRoute" # https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways
}

###############################################################################################################
# Virtual Network Gateway (VPN) (https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) #
###############################################################################################################

vpnGateway = {
  sku                = "VpnGw2"
  type               = "RouteBased"
  generation         = "Generation2"
  sharedKey          = "GatewayConnection"
  enableBgp          = false
  enableActiveActive = false
  pointToSiteClient = {
    certificateName = ""
    certificateData = ""
    addressSpace = [
    ]
  }
}

##########################################################################################################################
# Local Network Gateway (VPN) (https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#lng) #
##########################################################################################################################

vpnGatewayLocal = {
  fqdn    = "" # Set the fully-qualified domain name (FQDN) of your on-premises VPN gateway device
  address = "" # or set the public IP address. Do NOT set both "fqdn" and "address" parameters
  addressSpace = [
  ]
  bgp = {
    enable         = false
    asn            = 0
    peerWeight     = 0
    peeringAddress = ""
  }
}

#######################################################################################################################################
# Virtual Network Gateway (ExpressRoute) (https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) #
#######################################################################################################################################

expressRouteGateway = {
  sku = "" # https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways#gwsku
  connection = {
    circuitId        = ""    # Expected format = "/subscriptions/[subscription_id]/resourceGroups/[resource_group_name]/providers/Microsoft.Network/expressRouteCircuits/[circuit_name]"
    authorizationKey = ""
    enableFastPath   = false # https://learn.microsoft.com/azure/expressroute/about-fastpath
  }
}

######################################################################
# Monitor (https://learn.microsoft.com/azure/azure-monitor/overview) #
######################################################################

monitor = {
  enablePrivateLink = false # https://learn.microsoft.com/azure/azure-monitor/logs/private-link-security
}
