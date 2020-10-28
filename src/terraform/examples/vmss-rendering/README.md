# Best Practices for using Azure Virtual Machine Scale Sets (VMSS) or Azure Cycle Cloud for Rendering 

Animation and VFX Rendering have two major requirements for render nodes:
1. **Lowest cost of ownership** - studios operate on razor thin margins
1. **Thousands of compute cores** - animation and VFX require an enormous amount of compute power

The following are best practices for configuring Azure Virtual Machine Scale Sets (VMSS) or Azure Cycle Cloud for rendering to meet these two requirements:

1. To minimize TCO:
    1. Use [Azure Spot Virtual Machines](https://azure.microsoft.com/en-us/pricing/spot/) and set policy to "Delete".
    1. Use [Ephemeral OS disks for Azure VMs](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/ephemeral-os-disks)
    1. Don't specify `zones`.  This ensures there are no traffic charges between zones ([starting Feb 1, 2021](https://azure.microsoft.com/en-us/pricing/details/bandwidth/))
1. Adjust properties so machines are free to deploy anywhere in region:
    1. set `singlePlacementGroup` to false.  This will also increase the limit > 100.
    1. set `platformFaultDomainCount` to 1.
    1. set `enableAcceleratedNetworking` to false.
    1. (covered above) don't specify `zones`
    1. don't specify `proximityPlacementGroup`
    1. don't specify `additionalCapabilities`
1. Set `overprovision` to false, so machines don't temporarily run and then get destroyed leading to problems and delays with the render managers.
1. If using custom images, and scaling above 1k-2k nodes, use [Azure Shared Image Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries).
1. Once using > 1000 nodes consider using [Azure Cycle Cloud](https://azure.microsoft.com/en-us/features/azure-cyclecloud/) for help with the complexity of managing multiple VMSS instances at the same time and best option for itegration with the render manager.  The best practices and settings above, apply to [Azure Cycle Cloud](https://azure.microsoft.com/en-us/features/azure-cyclecloud/).

In this directory are terraform and ARM template examples to demonstrate how to achieve all of the above properties.  Closely related is deployment performance, and there are [best practices for improving virtual machine performance](https://github.com/Azure/Avere/blob/main/docs/azure_vm_provision_best_practices.md).

## Terraform Deployment

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).  For more information see the [linux_virtual_machine_scale_set](https://www.terraform.io/docs/providers/azurerm/r/linux_virtual_machine_scale_set.html) page.

1. browse to https://shell.azure.com

1. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

1. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin main
```

1. `cd src/terraform/examples/vmss-rendering`

1. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

1. execute `terraform init` in the directory of `main.tf`.

1. execute `terraform apply -auto-approve` to deploy the VMSS

Once deployed you will be able to login to the nodes and inspect the properties.

When you are done using the vmss, you can destroy it by running `terraform destroy -auto-approve`.

## ARM Template Deployment

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).  For more information see the [virtualmachinescalesets template reference page](https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/2019-03-01/virtualmachinescalesets)

1. browse to https://shell.azure.com

1. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

1. Ensure you have created a VNET with a subnet.  You can use the terraform example above for this example.

1. get the examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin main
```

1. `cd src/terraform/examples/vmss-rendering`

1. `code azuredeploy.parameters.json` to edit the local variables section at the top of the file, to customize to your preferences, including your VNET

1. execute the following commands to create the new resource group and deploy the template:

```bash
export SUBSCRIPTION=#REPLACE WITH YOUR SUBSCRIPTION
export LOCATION=#REPLACE WITH LOCATION
export RESOURCE_GROUP=#REPLACE WITH NEW RESOURCE GROUP NAME
az account set --subscription $SUBSCRIPTION
az group create --location $LOCATION --name $RESOURCE_GROUP
az group deployment create --resource-group $RESOURCE_GROUP --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
```

Once deployed you will be able to login to the nodes and inspect the properties.

When you are done using the vmss, you can destroy it by deleting the resource group `terraform destroy -auto-approve`.
