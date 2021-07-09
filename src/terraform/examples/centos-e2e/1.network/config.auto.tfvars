# the network resource group name
network_rg = "tfnetwork_rg"

// virtual network settings
vnet_name     = "vnet"
address_space = "10.0.0.0/16"

// The gateway subnet to hold the VPN gateway
// Azure requires the name "GatewaySubnet" to hold VPN gateway
gateway_subnet_name = "GatewaySubnet"
gateway_subnet      = "10.0.0.0/24"

// The subnet to hold the cache
// HPC Cache or the Avere vFXT must be in its own subnet
cache_subnet_name = "cache"
cache_subnet      = "10.0.1.0/24"

// The subnet for the rendernodes
rendernodes_subnet_name = "rendernodes"
rendernodes_subnet      = "10.0.4.0/22"

// VPN Gateway configuration
// generation and sku defined in https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark
vpngw_generation = "Generation2"
vpngw_sku        = "VpnGw2"
