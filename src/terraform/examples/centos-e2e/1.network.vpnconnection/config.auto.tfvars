# set to true if using the simulated on-prem network, otherwise false
use_onprem_simulation = true

# only update below values if use_onprem_simulation set to false
real_onprem_address_space   = "172.16.0.0/16"
real_onprem_vpn_address     = "x.x.x.x"
real_onprem_vpn_bgp_address = "172.16.0.1"
real_onprem_vpn_asn         = 64512
