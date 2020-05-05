# CacheWarmer for HPC Cache

This is an example of how to setup the CacheWarmer for HPC [Azure HPC Cache](https://azure.microsoft.com/services/hpc-cache/).

The CacheWarmer runs as a service on the jumpbox, and watches a pre-defined directory for a job file.  The job file describes the HPC Cache mount addresses, export path, and path to warm.  For example, the following file is an example of this file:

```bash
{
  "WarmTargetMountAddresses": [
    "10.0.1.11",
    "10.0.1.12",
    "10.0.1.13"
  ],
  "WarmTargetExportPath": "/animation",
  "WarmTargetPath": "/scene1"
}
```

The CacheWarmer will then automatically start VMSS SPOT instances to warm the target through each of the mount addresses.  Once warmed, the VMSS instances will be destroyed.

This examples configures a render network, jumpbox, and HPC Cache with 1 filer as shown in the diagram below:

![The architecture](../../../../../docs/images/terraform/cachewarmer-hpcc.png)

To simulate latency, the NFS filer will live in a different vnet, resource group, and region.

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

5. `cd src/terraform/examples/HPC\ Cache/vmss`

6. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to build the HPC Cache cluster

Once installed you will be able to see the VMSS nodes mounted on the HPC Cache.

When you are done using the cluster, you can destroy it by running `terraform destroy -auto-approve` or just delete the resource groups created.