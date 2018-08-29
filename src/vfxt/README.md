# Avere vFXT cluster controller node - ARM template deployment

This 30 minute deployment uses an ARM template to create from scratch all the necessary infrastructure to support an Avere vFXT for Azure cluster, including the VNet and the cluster controller.  By the end of the demo you will have the resources shown in the following diagram:

<img src="../../docs/images/vfxt_deployment.png"> 

As you go through this deployment, save the following important output values for later use.  You can use the following tracking table to add your values as you proceed through the deployment - save it in a safe place.

|Key|Value|
|---|---|
|Location|`region value from output after deploying controller, for example "eastus2"`|
|Controller SSH String|`ssh string output after controller deployment`|
|Subnet ID|`value from output after deploying controller`|
|Avere Management IP|`IP address output during cluster creation`|
|Avere vFXT NFS IP Range CSV|`A CSV list of IP address output by the vFXT`|
|Encryption Key|`from Avere vFXT Management EP - covered in Using the vFXT`|

# Deploy the Avere cluster controller and VNet

The cluster controller helps you install and manage an Avere vFXT cluster.

You can deploy the Avere vFXT through the portal, or through the cloud shell.  Before deploying, please review the [vFXT prerequisites](../../docs/prereqs.md).

## Portal install

To install from the portal, launch the deployment by clicking the "Deploy to Azure" button here:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Favereimageswestus.blob.core.windows.net%2Fgithubcontent%2Fsrc%2Fvfxt%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

Save the output values of the deployment for the vFXT deployment, and capture `location`, `sshString`, and `subnetref` to your tracking table described at the beginning of this document.

## Cloud Shell install

1. To deploy the controller, first open a cloud shell from the [portal](http://portal.azure.com) or [cloud shell](https://shell.azure.com/).

2. If this is your first time using the Avere templates from this subscription, you will need to accept the legal terms.  Change the cloud shell to PowerShell mode and accept the terms for your subscription by running the following commands (use your actual subscription ID in place of the ``#SUBSSCRIPTION_ID`` term in this example):

  ```powershell
  PS C:\> Select-AzureRmSubscription -SubscriptionID #SUBSCRIPTION_ID
  PS C:\> Get-AzureRmMarketplaceTerms -Publisher "microsoft-avere" -Product "vfxt" -Name "avere-vfxt-controller" | Set-AzureRmMarketplaceTerms -Accept
  PS C:\> Get-AzureRmMarketplaceTerms -Publisher "microsoft-avere" -Product "vfxt" -Name "avere-vfxt-node" | Set-AzureRmMarketplaceTerms -Accept
  ```

3. Change the cloud shell back to a Linux shell, and run the following commands in cloud shell to deploy. Use your values in place of the commented variables. 

  ```bash
  # set the subscription, resource group, and location
  export DstSub=#"SUBSCRIPTION_ID"
  export DstResourceGroupName=#"exampleresourcegroup"
  export DstLocation=#"eastus2"

  # get the Avere cluster controller template and edit parameters
  curl -o azuredeploy.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/vfxt/azuredeploy.json
  curl -o azuredeploy.parameters.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/vfxt/azuredeploy.parameters.json
  vi azuredeploy.parameters.json

  # deploy the template
  az account set --subscription $DstSub
  az group create --name $DstResourceGroupName --location $DstLocation
  az group deployment create --resource-group $DstResourceGroupName --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
  ```

4. Scroll up in the deployment output to the section labeled `"outputs"` and copy the values to save. Be sure to capture `location`, `sshString`, and `subnetref` and add them to your tracking table described at the beginning of this document.

# Next steps

Now that you have deployed the cluster controller node, these are the next steps:
  1. [Deploy the vFXT cluster](../../docs/jumpstart_deploy.md)
  2. [Access the vFXT cluster](../../docs/access_cluster.md)
  3. [Configure Storage](../../docs/configure_storage.md) - configure cloud storage using your new storage account created in this example.
