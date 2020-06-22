# A Houdini Render Farm on Azure

This example shows how to configure the end to end infrastructure for a Houdini render farm on azure.  This example provides the azure infrastructure required to implement a [Houdini RenderFarm](https://www.sidefx.com/faq/question/indie-renderfarm-setup/) ([also described here](http://www.sidefx.com/docs/houdini/render/cloudfarm.html#rendering-on-cloud)).  The architecture includes a license server, an HQueue server, cloud cache and render nodes:

![The architecture](../../../../docs/images/terraform/houdini.png)

## Deployment Instructions

The deployment instructions are based on the [first render pilot document](https://aka.ms/first-render-pilot) with two phases:
1. **Phase 1: first frame render** - this sets up the pre-requisites of network, storage, render node, and supporting nodes
    1. **0.network** - build out the virtual network on Azure and connect to onprem if required.
    1. **1.storage** - build a backing storage solution: this could connecting back to on-prem filer, or all in cloud blob storage, or cloud filer.
    1. **2.base image** - this step builds the license server, queue server, and render node.  At this point you should be able to render your first frame
1. **Phase 2: scaling the render farm**
    1. **3.cache** - build out the Avere cache
    1. **4.rendernodes** - scale the render nodes with VMSS

## Pre-requisites

Before running the examples you will need to setup the following pre-requisites:

1. **cloudshell** - all setup can be run through cloudshell.  You can also setup your own environment, but you will need ssh, git, az cli, and terraform.
    1. browse to https://shell.azure.com

    1. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

    1. to enable the ability to run the cache, execute the following `az vm image accept-terms --urn microsoft-avere:vfxt:avere-vfxt-controller:latest`: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs

    1. If not already installed, run the following commands to install the Avere vFXT provider for Azure:
    ```bash
    mkdir -p ~/.terraform.d/plugins
    # install the vfxt released binary from https://github.com/Azure/Avere
    wget -O ~/.terraform.d/plugins/terraform-provider-avere https://github.com/Azure/Avere/releases/download/tfprovider_v0.9.1/terraform-provider-avere
    chmod 755 ~/.terraform.d/plugins/terraform-provider-avere
    ```

    1. get the terraform examples
    ```bash
    mkdir tf
    cd tf
    git init
    git remote add origin -f https://github.com/Azure/Avere.git
    git config core.sparsecheckout true
    echo "src/terraform/*" >> .git/info/sparse-checkout
    git pull origin master
    ```

1. **storage** - if using an on-prem filer, you will need to establish an [Azure VPN Gateway](https://azure.microsoft.com/en-us/services/vpn-gateway/) to on-premises for connectivity to backend storage, rendering license server, active directory server, or render manager.  This step is configured after building out the Virtual Network in step 0 below.

## Phase 1: Step 0 - Network

The first step is to setup the Virtual Network, subnets, and network security groups:

1. continuing from the previous instructions browse to the houdini network directory: `cd ~/tf/src/terraform/examples/vfxt/houdinienvrionment/0.network`

1. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences.

1. execute `terraform init` in the directory of `main.tf`.

1. execute `terraform apply -auto-approve` to build the vfxt cluster

Once deployed, capture the output variables to somewhere safe, as they will be needed in the following deployments.

Once your virtual network is setup, determine if you need to establish an [Azure VPN Gateway](https://azure.microsoft.com/en-us/services/vpn-gateway/) to on-premises for connectivity to backend storage, rendering license server, active directory server, or render manager.

## Phase 1: Step 1 - Storage

The next step is to establish backend storage.  If using a backend storage filer, you can skip this step.  Otherwise if you are using cloud based storage, proceed through the following steps:

1. decide whether to use blob based storage or an nfs filer and run the following steps:
    1. if using blob based storage: `cd ~/tf/src/terraform/examples/vfxt/houdinienvrionment/1.storage`
