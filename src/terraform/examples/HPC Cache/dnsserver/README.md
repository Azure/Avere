# HPC Cache + DNS Spoofing using Unbound DNS server with Split Horizen

This deploys the 1-filer vFXT example, and an Azure virtual machine that installs and configures [Unbound](https://nlnetlabs.nl/projects/unbound/about/) and configures it to override the address of an on-premises filer so that the render nodes mount the Avere to hide the latency.  All other dns requests are forwarded to pre-configured on-premises dns servers.

![The architecture](../../../../docs/images/terraform/1filerdns.png)

## Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin main
```

4. `cd src/terraform/examples/dnsserver`

7. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to deploy the dns server and cluster

10. use the output DNS ip address to populate the dns servers on your vnet.

Here are some dig commands to test your records:
```bash
# to lookup the A record for nfs1.rendering.com to unbound server 10.0.3.253
dig A @10.0.3.253 nfs1.rendering.com

# to do a reverse lookup to one of the vfxt addresses to unbound server 10.0.3.253
dig  @10.0.3.253 -x 10.0.1.200
```

Once installed you will be able to point all the cloud nodes using avere at the DNS server.

When you are done, you can destroy all resources by running `terraform destroy -auto-approve`.