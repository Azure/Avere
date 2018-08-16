
# HTTPS access for cluster nodes

Although the individual vFXT cluster nodes are not hardened for open internet access, there are some features that require secure connections from outside the virtual network.

After creating the cluster, configure port 443 on all nodes to allow inbound and outbound access. This configuration allows HTTPS connections for the following tasks:

- Accessing the Avere Control Panel for cluster monitoring and administration
- Downloading Avere OS software upgrades
- Uploading system status and troubleshooting information to Avere Global Services

The [Required ports](required_ports.md) reference lists other recommended port settings.