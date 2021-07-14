# the network resource group name
network_rg = "tfnetwork_rg"
ssh_port   = 22

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

// There are 3 VNET choices
// NoVpn        - does nothing, customer will setup ExpressRoute 
//                gateway, or some other connectivity to onprem
// VpnIPsec     - creates an IPsec Tunnel
// VpnVnet2Vnet - creates an Azure Vnet to Vnet tunnel
on_prem_connectivity = "VpnVnet2Vnet"

// VPN Gateway configuration, unused if set to ExpressRoute
// generation and sku defined in https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark
vpngw_generation = "Generation2"
vpngw_sku        = "VpnGw2"

// An onprem proxy is a common way to avoid egress from the cloud
// all control plane traffic goes through the proxy.  Customers have found
// that the higher latency for the control plane traffic does not affect operations
// much.
use_proxy_server = true
proxy_uri        = "http://172.16.1.253:3128"

# replace with onprem dns servers, otherwise points at the simulated dns
# if using the onprem simulator, the first entry must match
# note that the Azure DNS "168.63.129.16" is only used in the 
# initial deployment for bootstrapping purposes
onprem_dns_servers = ["172.16.1.254", "168.63.129.16"]
# a space separted list of domains, if no search domain, leave empty
dns_search_domain = ""

# the spoof dns server is used to redirect cloud clients to HPC Cache or
# Avere vFXT instead of the onprem filer
use_spoof_dns_server = true
spoof_dns_server     = "10.0.1.253"
