# CacheWarmer for Avere vFXT for Azure

This is an example of how to setup the CacheWarmer for [Avere vFXT for Azure](https://docs.microsoft.com/en-us/azure/avere-vfxt/).  The CacheWarmer is a golang program that runs as a systemd service on the controller and the source code is located under the [golang source](../../../../go/cmd/cachewarmer).

The CacheWarmer runs as a system service on the controller, and watches an azure storage queue for a job entry.  The job entry describes the HPC Cache mount addresses, export path, and path to warm.  For example, the following file is an example of a job entry:

TODO - replace below
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

This examples configures a render network, controller, and Avere vFXT with 1 filer as shown in the diagram below:

![The architecture](../../../../../docs/images/terraform/cachewarmer.png)

To simulate latency, the NFS filer will live in a different vnet, resource group, and region.

A nfs filer will be used to hold the bootstrap directory and the warm job directories.  The terraform example demonstrates how to chain up the terraform modules including deployment of the vFXT, mounting all junctions, install the CacheWarmer, and finally the job submission.  The job submission blocks until the cache is warmed.

![The architecture](../../../../../docs/images/terraform/cachewarmerpipeline.png)

# CacheWarmer Components

The CacheWarmer has 4 components, and may be installed in an air-gapped environment.  Please read each module description to learn how to deploy each in an air-gapped environment.

## CacheWarmer Prepare Bootstrap Module

- describe the proxy support for the module
- describe the scripts for airgapped, 

## CacheWarmer Install Manager Module

- describe the airgapped, but point to how to setup terraform on internal node, because you can't use cloud shell
- describe the requirement for controller

## CacheWarmer Install Worker Module

- describe the airgapped, but point to how to setup terraform on internal node, because you can't use cloud shell

## CacheWarmer Submit Jobs Module

- describe how to submit jobs
- two alternatives
  - command line
  - use storage sdk to submit items to the queue, and show the job format

# Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell, but you can use in your own environment.  If you are installing into your own environment, follow the [instructions to setup terraform and the vFXT provider](../pipeline) for the environment closest to yours.

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. double check your Avere vFXT prerequisites, including running `az vm image terms accept --urn microsoft-avere:vfxt:avere-vfxt-controller:latest`: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs

4. If not already installed, run the following commands to install the Avere vFXT provider for Azure:
```bash
version=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name | sed -e 's/[^0-9]*\([0-9].*\)$/\1/')
browser_download_url=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .assets[].browser_download_url | grep -e "terraform-provider-avere$")
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64
wget -O ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64/terraform-provider-avere_v$version $browser_download_url
chmod 755 ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64/terraform-provider-avere_v$version
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

6. `cd src/terraform/examples/vfxt/cachewarmer`

7. `code config.auto.tfvars` to edit the variables.  If you are using an [ssk key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys), ensure that ~/.ssh/id_rsa is populated.

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to build the vfxt cluster and the cachewarmer

Once installed you will be able to login and use the vFXT cluster according to the vFXT documentation: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-cluster-gui.

To submit additional directories for warming, you can rename the `cachewarmer_submitjobs` module, or insert a json entry in the storage queue in the following format ([Azure Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer/) makes this easy to do):

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

When you are done using the cluster, you can destroy it by running `terraform destroy -auto-approve` or just delete the three resource groups created.