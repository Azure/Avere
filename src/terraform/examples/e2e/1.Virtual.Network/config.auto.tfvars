resourceGroupName = "ArtistAnywhere.Network" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

#################################################################################################
# Virtual Network (https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) #
#################################################################################################

virtualNetworks = [
  {
    enable     = true
    name       = "Studio"
    regionName = "WestUS3"
    addressSpace = [
      "10.0.0.0/16"
    ]
    dnsAddresses = [
    ]
    subnets = [
      {
        name = "Farm"
        addressSpace = [
          "10.0.0.0/17"
        ]
        serviceEndpoints = [
          "Microsoft.Storage.Global"
        ]
        serviceDelegation    = ""
        denyOutboundInternet = false
      },
      {
        name = "Workstation"
        addressSpace = [
          "10.0.128.0/18"
        ]
        serviceEndpoints = [
          "Microsoft.Storage.Global"
        ]
        serviceDelegation    = ""
        denyOutboundInternet = false
      },
      {
        name = "Storage"
        addressSpace = [
          "10.0.192.0/24"
        ]
        serviceEndpoints = [
          "Microsoft.Storage.Global"
        ]
        serviceDelegation    = "" # "Microsoft.Netapp/volumes"
        denyOutboundInternet = false
      },
      {
        name = "Cache"
        addressSpace = [
          "10.0.193.0/24"
        ]
        serviceEndpoints = [
          "Microsoft.Storage.Global"
        ]
        serviceDelegation    = ""
        denyOutboundInternet = false
      },
      {
        name = "AI"
        addressSpace = [
          "10.0.194.0/24"
        ]
        serviceEndpoints = [
          "Microsoft.CognitiveServices"
        ]
        serviceDelegation    = "Microsoft.Web/serverFarms"
        denyOutboundInternet = false
      },
      {
        name = "GatewaySubnet"
        addressSpace = [
          "10.0.255.0/26"
        ]
        serviceEndpoints = [
        ]
        serviceDelegation    = ""
        denyOutboundInternet = false
      },
      {
        name = "AzureBastionSubnet"
        addressSpace = [
          "10.0.255.64/26"
        ]
        serviceEndpoints = [
        ]
        serviceDelegation    = ""
        denyOutboundInternet = false
      }
    ]
    subnetIndex = { # Must be in sync with corresponding subnet
      farm        = 0
      workstation = 1
      storage     = 2
      cache       = 3
      ai          = 4
    }
  },
  {
    enable     = true
    name       = "Studio"
    regionName = "EastUS2"
    addressSpace = [
      "10.1.0.0/16"
    ]
    dnsAddresses = [
    ]
    subnets = [
      {
        name = "Farm"
        addressSpace = [
          "10.1.0.0/17"
        ]
        serviceEndpoints = [
          "Microsoft.Storage.Global"
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
          "Microsoft.Storage.Global"
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
          "Microsoft.Storage.Global"
        ]
        serviceDelegation    = "" # "Microsoft.Netapp/volumes"
        denyOutboundInternet = false
      },
      {
        name = "Cache"
        addressSpace = [
          "10.1.193.0/24"
        ]
        serviceEndpoints = [
          "Microsoft.Storage.Global"
        ]
        serviceDelegation    = ""
        denyOutboundInternet = false
      },
      {
        name = "AI"
        addressSpace = [
          "10.1.194.0/24"
        ]
        serviceEndpoints = [
          "Microsoft.CognitiveServices"
        ]
        serviceDelegation    = "Microsoft.Web/serverFarms"
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
    subnetIndex = { # Must be in sync with corresponding subnet
      farm        = 0
      workstation = 1
      storage     = 2
      cache       = 3
      ai          = 4
    }
  }
]

################################################################################################################
# Virtual Network Peering (https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview) #
################################################################################################################

networkPeering = {
  enable                      = false
  allowRemoteNetworkAccess    = true
  allowRemoteForwardedTraffic = true
  allowGatewayTransit         = true
}

##########################################################################################################################
# Network Address Translation (NAT) Gateway (https://learn.microsoft.com/azure/virtual-network/nat-gateway/nat-overview) #
##########################################################################################################################

natGateway = {
  enable = true
}

############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

privateDns = {
  enable   = true
  zoneName = "artist.studio"
  autoRegistration = {
    enable = true
  }
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

###############################################################################################################
# Virtual Network Gateway (VPN) (https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) #
###############################################################################################################

vpnGateway = {
  enable             = false
  sku                = "VpnGw2"
  type               = "RouteBased"
  generation         = "Generation2"
  sharedKey          = ""
  enableBgp          = false
  enablePerRegion    = false
  enableActiveActive = false
  pointToSiteClient = {
    addressSpace = [
    ]
    rootCertificate = {
      name = ""
      data = ""
    }
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

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

existingNetwork = {
  enable            = false
  name              = ""
  regionName        = ""
  resourceGroupName = ""
}
