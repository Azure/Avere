# CacheWarmer for Avere vFXT for Azure

This is an example of how to setup the CacheWarmer for [Avere vFXT for Azure](https://docs.microsoft.com/en-us/azure/avere-vfxt/).  The CacheWarmer is a golang program that runs as a systemd service on the controller and the source code is located under the [golang source](../../../../go/cmd/cachewarmer).

The CacheWarmer watches a pre-defined directory for a job file.  The job file describes the HPC Cache mount addresses, export path, and path to warm.  For example, the following file is an example of a job file:

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

A nfs filer will be used to hold the bootstrap directory and the warm job directories.  The example is broken into 3 phases.  The third phase demonstrates how to chain up the terraform modules to including deployment of the vFXT, mounting all junctions, building and installation of the CacheWarmer, and finally the job submission.  Once the 3 phase has completed the cache is warmed with the desired content.

![The architecture](../../../../../docs/images/terraform/cachewarmerpipeline.png)

## Deploy the Virtual Networks and Filer

These steps deploy the virtual networks and filer.  It is best to spread the filer network in a separate region from the Avere vFXT so that latency exists.

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

2. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin main
```

3. `cd src/terraform/examples/vfxt/cachewarmer/1.networkandfiler`

4. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences.  This is where you can spread the two networks across regions.  If you are using an [ssk key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys), ensure that ~/.ssh/id_rsa is populated.

5. execute `terraform init` in the directory of `main.tf`.

6. execute `terraform apply -auto-approve` to deploy the virtual networks and the filer

7. save the output to use for the installation of the Avere vFXT.

## Deploy the vFXT controller

These steps install the vFXT controller.

1. using the existing https://shell.azure.com, change to `2.vfxtcontroller`

```bash
cd ~/tf/src/terraform/examples/vfxt/cachewarmer/2.vfxtcontroller
```

3. double check your Avere vFXT prerequisites, including running `az vm image accept-terms --urn microsoft-avere:vfxt:avere-vfxt-controller:latest`: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs

4. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences including pasting in the output values from the previous deployment.

5. execute `terraform init` in the directory of `main.tf`.

6. execute `terraform apply -auto-approve` to build the vfxt controller

7. Now logon to the controller and jump to the filer to prepare content.  One good potential content is the [Moana Island Scene from  Walt Disney Animation Studios](https://www.technology.disneyanimation.com/islandscene).

## Deploy the vFXT and the CacheWarmer

These steps install the vFXT and the cachewarmer and submit a job.

1. using the existing https://shell.azure.com, change to `3.vfxtandcachewarmer`

```bash
cd ~/tf/src/terraform/examples/vfxt/cachewarmer/3.vfxtandcachewarmer
```

2. If not already installed, run the following commands to install the Avere vFXT provider for Azure:
```bash
mkdir -p ~/.terraform.d/plugins
# install the vfxt released binary from https://github.com/Azure/Avere
wget -O ~/.terraform.d/plugins/terraform-provider-avere https://github.com/Azure/Avere/releases/download/tfprovider_v0.9.4/terraform-provider-avere
chmod 755 ~/.terraform.d/plugins/terraform-provider-avere
```

3. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences.  Set the warm directory

4. execute `terraform init` in the directory of `main.tf`.

5. execute `terraform apply -auto-approve` to build the vfxt cluster and deploy and subnet the cache warmer job.  The cache warmer job submission will block until the cache warming process is complete.

To submit addition directories for warming, you would submit the `cachewarmer_submitjob` module, or you can write a file similar to the following to the warm directory in this example `/.cachewarmjob` folder on the vFXT:

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
