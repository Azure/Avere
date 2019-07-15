# Setting MTU for your VNET

Based on the ‘[important note](https://docs.microsoft.com/en-gb/azure/vpn-gateway/vpn-gateway-about-vpn-devices#ipsec)’ section of this VPN article there are two solutions to avoid MTU mismatch network failures:
1. **Clamp TCP MSS at 1350** – this is done using your firewall rules on your on-premesis network appliance for its gateway connection to Azure.
1.  Or alternatively, **set MTU to 1400 on the Azure Side** – this will need to be done in two places:
    1. **Custom Image** – add the line MTU=1400 to /etc/sysconfig/network-scripts/ifcfg-eth0
    1. **Avere** – this is done by either browsing to the web ui something like https://10.30.1.5/avere/fxt/vlans.php (manually adding /avere/fxt/vlans.php) or executing the following line on the Avere controller:
    ```
    averecmd cluster.modifyVLAN '{"router": "10.30.1.1", "mtu": "1400", "name": "default", "roles": "client,cluster,core_access,mgmt", "id": "0"}'
    ```