# Networking Best Practices for Rendering

Animation and VFX Rendering have two major requirements for networking:
1. **Lowest cost of ownership** - studios operate on razor thin margins
1. **On-prem to cloud networking Bandwidth** - burst rendering leverages on-premises storage.

## Azure Virtual Network

For lowest TCO, on [Azure Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview):
* Avoid peering VNETs in the same region, as this will lead to inter-peering same region cross charges, as the VMs reach across to the storage appliance.  Instead fit all render workloads into the same VNET, and use subnets to separate them. 
* An example configuration for a rendering Virtual Network configuration with rules are the following:
    1. [Render Network](../../modules/render_network/) - describes a standard render network
    2. [Secure Network](../../modules/render_network_secure/) - describes a secure render network where internet traffic only goes over internet.
* For a VPN Gateway or ExpressRoute Gateway you will need to define a subnet named `GatewaySubnet`, and it can be [as small as a /28](https://docs.microsoft.com/en-us/azure/vpn-gateway/tutorial-site-to-site-portal#create-the-gateway).
* One common scenario for rendering customers is to peer VNETs across different subscriptions, where the subscriptions belong to different AD Tenants.  This is useful to share rendered content on trusted networks for quality check (QC) or final review.  The technique for doing this is described in the document [Create a virtual network peering - Resource Manager, different subscriptions and Azure Active Directory tenants](https://docs.microsoft.com/en-us/azure/virtual-network/create-peering-different-subscriptions).

## Azure VPN Gateway

The [Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) is the quickest way to setup a direct connection to on-premises over the internet.

For lowest TCO:
* automate the VPN in something like ARM templates or Terraform, and only deploy when needed, but destroy when not needed
* avoid zone redundant gateways to save the cross zonal network charges ([starting Feb 1, 2021](https://azure.microsoft.com/en-us/pricing/details/bandwidth/)) to VMs.  For example, prefer [Gateway SKU](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark) VpnGw3 vs. VpnGw3AZ.

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

The [Azure Virtual WAN](https://docs.microsoft.com/en-us/azure/virtual-wan/virtual-wan-about) is another approach to increase the 1Gbps limit of the Azure VPN Gateway to 20Gbps.  Each [Virtual Wan hub can go up to 20 Gbps](https://docs.microsoft.com/en-us/azure/virtual-wan/virtual-wan-about#what-is-the-total-vpn-throughput-of-a-vpn-tunnel-and-a-connection) where throughput is shared across individual 1Gbps tunnels.

## Azure ExpressRoute
The [Azure ExpressRoute](https://azure.microsoft.com/en-us/services/expressroute/), enables up to 100Gbps private direct connection to Azure.

### Pre-requisites:
* Ensure your on-premises switch support [QinQ VLAN Tagging](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about#vlan-tagging) or [Dot1Q VLAN Tagging](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about#vlan-tagging)
* For installations larger than 10Gbps, work with the Microsoft Rendering and ExpressRoute teams to ensure the established architecture will provide the best performance.
* For LOA preparation for ExpressRoute Direct, if you are not familiar with Windows or Powershell, use the cloudshell instructions described in the [github documentation enhancement](https://github.com/MicrosoftDocs/azure-docs/issues/67305) to send the [LOA to your service provider](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-howto-erdirect).

### For TCO considerations, the here is the cost break down of ExpressRoute
* consider [ExpressRoute Direct](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about), as this may save you the cost of ExpressRoute + connectivity partner.  [ExpressRoute Direct](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about) is based on the concept of physical port pairs. ER Direct is available with port pairs at 10Gbps or 100Gbps.  Over the ExpressRoute port pair is [possible to configure multiple ExpressRoute circuits at different bandwidths](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-erdirect-about).  One of key features that ExpressRoute Direct provides is the Massive Data Ingestion through dedicated port pair with the Microsoft Enterprise Edge (MSEE) routers.
* avoid [zone redundant gateways](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways#aggthroughput) to save cross zonal network charges ([starting Feb 1, 2021](https://azure.microsoft.com/en-us/pricing/details/bandwidth/)).  For example, choose "Ultra Performance SKU" over "ErGw3AZ".
* avoid ExpressRoute unlimited SKUs, due to the bursty nature of rendering as it requires saturation of the pipe more than 70% of the time.
* To save on egress costs, if your data is close to an ExpressRoute location, explore the availability of [ExpressRoute Local](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-faqs#what-is-expressroute-local).  ExpressRoute Local may also be combined with ExpressRoute Direct.

### Ensuring for highest performance:
* ensure BGP and ECMP (Equal-Cost-Multi-Path) is enabled
* ensure [ExpressRoute FastPath](https://docs.microsoft.com/en-us/azure/expressroute/about-fastpath) is enabled.  Note that FastPath doesn't [support UDR, VNET Peering, Basic Load Balancer, or private link](https://docs.microsoft.com/en-us/azure/expressroute/about-fastpath), but these are rare to use for rendering, so it is safe to enable FastPath.  FastPath is designed to improve the data path performance between your on-premises network and your virtual network. When enabled, FastPath sends network traffic directly to virtual machines in the virtual network, bypassing the ExpressRoute gateway. Fast path is supported only in UltraPerformance and ErGw3AZ SKUs.  However, per the TCO considerations above prefer UltraPerformance over ErGw3AZ to avoid cross zonal charges ([starting Feb 1, 2021](https://azure.microsoft.com/en-us/pricing/details/bandwidth/)).
* The maximum transmission unit (MTU) for the ExpressRoute interface is 1500Byte
* consider using flow based ECMP that will allow for [bursting two times beyond the procured bandwidth](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-faqs#if-i-pay-for-an-expressroute-circuit-of-a-given-bandwidth-do-i-have-the-ability-to-use-more-than-my-procured-bandwidth).

### Ensuring for reliability:
* ensure you configure and activitate BGP on both primary and secondary links on each express route circuit to achieve a [99.95% SLA](https://azure.microsoft.com/en-us/support/legal/sla/expressroute/v1_3/)
* To have a configuration with good resilience between the Azure VNet and on-premises network, it is recommended to deploy two Expressroute circuits in two different ExpressRoute locations. The Azure VNet will be linked with both of ExpressRoute circuits
* Consider a backup for ExpressRoute private peering.  There are two approaches:
    1. (around 45 minute failover, no cost) on-demand bring up using ARM templates or Terraform automation to run and deploy a VPN in the case that Express Route fails.
    1. (ongoing cost, fast failover) use S2S VPN as a backup for [ExpressRoute private peering](https://docs.microsoft.com/en-us/azure/expressroute/use-s2s-vpn-as-backup-for-expressroute-privatepeering).  Here is an additional article on how you to have an [ExpressRoute co-exist with a VPN gateway](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-howto-coexist-resource-manager).

### Ensuring for security:
* To ensure your ExpressRoute connection is encrypted end-to-end, consider configuring [IPsec over ExpressRoute for Virtual WAN](https://docs.microsoft.com/en-us/azure/virtual-wan/vpn-over-expressroute).

## Troubleshooting network speeds

Here are some tips to find bottlenecks in your ExpressRoute setup:
* use [iPerf3](https://iperf.fr/) to help you measure your bandwidth, and help to narrow down whether this is the physical network, or the transfer protocols.
* if more than one peering location, isolate peering location by using highest path pre-pending.  Then re-test your bandwidth.
* to isolate the gateway, use [Microsoft Peering](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-circuit-peerings#microsoftpeering).  This will require public ip addresses from on-prem to cloud, but these can be locked down with NSGs in the cloud but, firewall on-prem.  Then re-test your bandwidth.
