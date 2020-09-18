# Networking Best Practices for Rendering

Animation and VFX Rendering have two major requirements for networking:
1. **Lowest cost of ownership** - studios operate on razor thin margins
1. **On-prem to cloud networking Bandwidth** - burst rendering leverages on-premises storage.

## Azure VPN Gateway

The [Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) is the quickest way to setup a direct connection to on-premises over the internet.

For lowest TCO:
* automate the VPN in something like ARM templates or Terraform, and only deploy when needed, but destroy when not needed

Pitfalls to avoid:
* after VPN is setup, the MTU will need to be set according to this '[important note](https://docs.microsoft.com/en-gb/azure/vpn-gateway/vpn-gateway-about-vpn-devices#ipsec)'.  There are two recommended solutions:
    1. **Clamp TCP MSS at 1350** – this is done using your firewall rules on the firewall.  For a concrete example, here is the configuration for fortinet: search for string ‘set tcp-mss-sender 1350’ in the following article for how to do this: https://cookbook.fortinet.com/ipsec-vpn-microsoft-azure-56/.  Other [configuration guides can be found in the device configuration guides](https://docs.microsoft.com/en-gb/azure/vpn-gateway/vpn-gateway-about-vpn-devices#devicetable).
    1. 	**Or alternatively, set MTU to 1400 on the Azure Side** – this will need to be done in two places:
	    1. **Render VM Custom Image** – add the line `MTU=1400` to `/etc/sysconfig/network-scripts/ifcfg-eth0`
		1. **Avere** – this is done by either browsing to the VLANS page in the web ui something under `/avere/fxt/vlans.php` (manually adding `/avere/fxt/vlans.php` to Avere web UI) or executing the following line on one of the Avere vFXT nodes:
		`averecmd cluster.modifyVLAN '{"router": "10.30.1.1", "mtu": "1400", "name": "default", "roles": "client,cluster,core_access,mgmt", "id": "0"}'`
* if you are blocked try looking at the on-prem firewall.  We have observed the following:
    * change the changing the terminating interface on the firewall.  We had a case happen where everything was running fine, but the tunnel would just not come up.  As a last resort we changed the terminating interface on the firewall, and it worked.
    * corruption is detected, and the firewall is PFSense, determine if interface on the PFSense is set to physical and not virtualized (putting on VTI).  We had a case where corruption was observed, and switching from physical to VTI resolved the issue.

## Virtual WAN

The [Azure Virtual WAN](https://docs.microsoft.com/en-us/azure/virtual-wan/virtual-wan-about) is another approach to increase the 1Gbps limit of the Azure VPN Gateway to 20Gbps.

## Azure ExpressRoute

The [Azure ExpressRoute](https://azure.microsoft.com/en-us/services/expressroute/), enables up to 100Gbps private direct connection to Azure.

### Pre-requisites:
* Ensure your on-premises switch support [QinQ VLAN Tagging](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about#vlan-tagging) or [Dot1Q VLAN Tagging](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about#vlan-tagging)
* For installations larger than 10Gbps, work with the Microsoft Rendering and ExpressRoute teams to ensure the established architecture will provide the best performance.

### For TCO considerations, the here is the cost break down of ExpressRoute
* consider [ExpressRoute Direct](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about), as this may save you the cost of ExpressRoute + connectivity partner.  [ExpressRoute Direct](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about) is based on the concept of physical port pairs. ER Direct is available with port pairs at 10Gbps or 100Gbps.  Over the ExpressRoute port pair is [possible to configure multiple ExpressRoute circuits at different bandwidths](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about).  One of key features that ExpressRoute Direct provides is the Massive Data Ingestion through dedicated port pair with the Microsoft Enterprise Edge (MSEE) routers.
* do not use or specify zones to save cross zonal network charges
* avoid ExpressRoute unlimited SKUs, due to the bursty nature of rendering as it requires saturation of the pipe more than 70% of the time.

### Ensuring for highest performance:
* ensure BGP and ECMP (Equal-Cost-Multi-Path) is enabled
* ensure [ExpressRoute FastPath](https://docs.microsoft.com/en-us/azure/expressroute/about-fastpath) is enabled.  Note that FastPath doesn't [support UDR, VNET Peering, Basic Load Balancer, or private link](https://docs.microsoft.com/en-us/azure/expressroute/about-fastpath), but these are rare to use for rendering, so it is safe to enable FastPath.  FastPath is designed to improve the data path performance between your on-premises network and your virtual network. When enabled, FastPath sends network traffic directly to virtual machines in the virtual network, bypassing the ExpressRoute gateway. Fast path is supported only in UltraPerformance and ErGw3AZ SKUs.  However, per the TCO considerations above prefer UltraPerformance over ErGw3AZ to avoid cross zonal charges.
* The maximum transmission unit (MTU) for the ExpressRoute interface is 1500Byte

### Ensuring for reliability:
* To have a configuration with good resilience between the Azure VNet and on-premises network, it is recommended to deploy two Expressroute circuits in two different ExpressRoute locations. The Azure VNet will be linked with both of ExpressRoute circuits

### Ensuring for security:
* To ensure your ExpressRoute connection is encrypted end-to-end, consider configuring [IPsec over ExpressRoute for Virtual WAN](https://docs.microsoft.com/en-us/azure/virtual-wan/vpn-over-expressroute).

## Troubleshooting network speeds

Here are some tips to find bottlenecks in your ExpressRoute setup:
* use [iPerf3](https://iperf.fr/) to help you measure your bandwidth, and help to narrow down whether this is the physical network, or the transfer protocols.
* if more than one peering location, isolate peering location by using highest path pre-pending.  Then re-test your bandwidth.
* to isolate the gateway, use [Microsoft Peering](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-circuit-peerings#microsoftpeering).  This will require public ip addresses from on-prem to cloud, but these can be locked down with NSGs in the cloud but, firewall on-prem.  Then re-test your bandwidth.
