# Simulated On-premises Environment

This folder contains a simulated on-premises environment.  The components are summarized as follows:
* **VPN Server** - this is a VPN Gateway with Site-to-site configuration, or for more realistic example, create a [Vyos Image](../../vpn-single-tunnel-vyos#image-creation)
* **NFS Filer** - this is a linux server with NFS enabled.
* **Jumpbox** - this is a VM with access via a public IP address.
* **DNS Server** - this is a VM with access via a public IP address.  We deploy a DNS Server instead of Azure Private DNS since we are connecting VNET to VNET as described in [Azure Private DNS configuration](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances?toc=/azure/dns/toc.json#vms-and-role-instances])
* **Proxy** - A proxy is used to enabled an "air-gapped" cloud.  Studios have found that sending control plane traffic to an onprem proxy does not get impacted by latency, and the tradeoff is worthe the "air-gapped" locked down cloud VNET.