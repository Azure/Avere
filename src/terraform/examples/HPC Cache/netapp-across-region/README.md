# HPC Cache extends Azure NetApp Files across regions

An HPC Cache compliments [Azure NetApp Files](https://azure.microsoft.com/en-us/services/netapp/) by extending the reach of the Azure NetApp Files data outside of the region where the Azure NetApp service resides.  The HPC Cache provides the following advantages:

1. **Preserves Single Point of Truth** - the HPC Cache is a cache and preserves the single source of truth of the data located at the source NetApp volume.    This means there are none of the problems associated with replications including replication lag, data race conditions, and data corruption.

2. **HPC Cache Hides Latency** - the HPC Cache hides latency from clients mounting the Azure NetApp Files volume from a different region, so the clients receive low latency and high performance.

3. **HPC Cache makes efficient use of bandwidth** - the HPC Cache only pulls down the data it needs and only once for unchanged artifacts.  For serving tools binaries or render content, this may mean the difference between requiring a 1Gbps pipe vs. a 10Gbps pipe.

4. **HPC Cache and the Avere vFXT can be deployed to any region** - the HPC Cache and the [Avere vFXT](../../vfxt/netapp-across-region) can be deployed to regions where Azure NetApp Files does not exist as listed in the [region availability for the NetApp files](https://azure.microsoft.com/en-us/global-infrastructure/services/?products=netapp&regions=asia-pacific-east,asia-pacific-southeast,australia-central,australia-central-2,australia-east,australia-southeast,brazil-south,canada-central,canada-east,central-india,europe-north,europe-west,france-central,france-south,japan-east,japan-west,korea-central,korea-south,norway-east,norway-west,south-africa-north,south-africa-west,south-india,switzerland-north,switzerland-west,uae-central,uae-north,united-kingdom-south,united-kingdom-west,us-central,us-east,us-east-2,us-north-central,us-south-central,us-west,us-west-2,us-west-central,west-india,non-regional).  At the time of this writing Azure NetApp Files is in the same regions as HPC Cache except for Korea Central, so the Avere vFXT will be mostly required to meet this scenario.

The [NetApp document](https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-create-volumes#best-practice) mentions that Azure NetApp Files does not work with VNET peering across regions.  This is resolved by using the [Azure VNet-to-VNet VPN gateway solution](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal).  The VNet-to-VNet VPN gateway can be cheaper than VNET peering in some scenarios since you only pay for the egress and the VPN Gateway, and not both the ingress and egress of the VNET peering.

This example configures a render network, controller, and HPC Cache where the netapp is configured in a different region.  The VNet-to-VNet VPN gateway connects the two regions as shown in the following diagram.  A 1 Gbps link is configured but this can be configured to be [as high as 10 Gbps and as low as 100Mbps](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#gwsku).

![The architecture](../../../../../docs/images/terraform/netapp-across-region-hpcc.png)

## Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. double check your [HPC Cache prerequisites](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-prereqs)

4. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin master
```

5. `cd src/terraform/examples/HPC\ Cache/netapp-across-region`

8. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences.

9. execute `terraform init` in the directory of `main.tf`.

10. execute `terraform apply -auto-approve` to build the HPC Cache cluster

nce installed you will be able to mount the HPC Cache cluster, using the according to the `mount_addresses` output and following the [documentation](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-mount).

When you are done using the cluster, you can destroy it by running `terraform destroy -auto-approve` or just delete the resource groups created.