# Avere vFXT in a Proxy Environment

This example shows how to configure the vfxt in a secured locked down internet environment where access to outside resources is via a proxy.  The following tutorial video walks you through this full example:

[![Tutorial Video](proxyyoutube.png)](https://youtu.be/lxDDwu44OHM)

It configures a render network, controller, and vfxt with 1 filer and an Azure Blob Storage cloud core filer as shown in the diagram below:

![The architecture](../../../../../docs/images/terraform/proxy.png)

The [internet access](../../../../vfxt/internet_access.md) document discusses the Azure and internet security for Avere in further detail.

## Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell, but you can use in your own environment, ensure you install the vfxt provider as described in the [build provider instructions](../../../providers/terraform-provider-avere#build-the-terraform-provider-binary).  However, if you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. double check your Avere vFXT prerequisites, including running `az vm image accept-terms --urn microsoft-avere:vfxt:avere-vfxt-controller:latest`: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs

4. If not already installed, run the following commands to install the Avere vFXT provider for Azure:
```bash
mkdir -p ~/.terraform.d/plugins
# install the vfxt released binary from https://github.com/Azure/Avere
wget -O ~/.terraform.d/plugins/terraform-provider-avere https://github.com/Azure/Avere/releases/download/tfprovider_v0.9.13/terraform-provider-avere
chmod 755 ~/.terraform.d/plugins/terraform-provider-avere
```

5. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin main
```

6. `cd src/terraform/examples/vfxt/proxy`

7. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences.  If you are using an [ssk key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys), ensure that ~/.ssh/id_rsa is populated.

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to build the vfxt cluster

Once installed you will be able to login and use the vFXT cluster according to the vFXT documentation: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-cluster-gui.

Try to scale up and down the cluster, adjust the customer settings, add new junctions, etc, by editing the `main.tf`, and running `terraform apply -auto-approve`.

When you are done using the cluster, you can destroy it by running `terraform destroy -auto-approve` or just delete the three resource groups created.

## Safelist Urls

This proxy environment can be used to discover safe urls.  Run your tools, using the proxy address `https://proxy_ip:3128`, and then run the following on the proxy after you are complete:

```bash
sudo awk '{print $3 " " $7}' /var/log/squid/access.log | sort | uniq
```

The following table shows the safe urls required for Avere vFXT and az cli:

| Azure Service | Role | Safe Urls |
| --- | --- | --- |
| Azure Avere vFXTs | Render burst fast caching / performance caching | download.averesystems.com:443<BR>management.azure.com:443<BR>ACCOUNTNAME.blob.core.windows.net(if using blob storage for filer) |
| az cli | command line tool to create and manage azure resources | management.azure.com:443 |