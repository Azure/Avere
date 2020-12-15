# Secure Render VNET

This is an implementation of a secure VNET that has no access to the internet.  The virtual network has 3 subnets:
1. **Gateway** - this holds a VPN or ExpressRouteGateway
1. **cloud-cache** - this holds an HPC Cache, and potentially a cycle cloud instance.
1. **render** - this holds the render nodes


Notes
* The GatewaySubnet is owned by the gateway and cannot have an NSG associated with it
* the deny rules ensure the default rules at priority >=65000 do not get hit
* the deny in traffic will generate an error saying that an AzureLoadBalancer will not work.  This is fine since rendering architectures will not need load balancers.
