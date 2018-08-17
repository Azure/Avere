# Avere vFXT Controller - ARM template deployment

This 30 minute deployment uses an ARM template to create from scratch all the necessary infrastructure to support a vFXT including the VNET and the vFXT Controller.  By the end of the demo you will have the resources shown in the following diagram:

<img src="../../docs/images/vfxt_deployment.png">

As you go through this deployment, you will need to save the following important outputs for later use.  We recommend you fill in the following tracking table as you proceed through the deployment, and save it in a safe place.

|Key|Value|
|---|---|
|Location|`region value from output after deploying controller, eg. "eastus2"`|
|Controller SSH String|`ssh string output after controller deployment`|
|Subnet ID|`value from output after deploying controller`|
|Avere Management IP|`IP Address output during vFXT creation`|
|Avere vFXT NFS IP Range CSV|`A CSV list of IP Address output by the vFXT`|
|Encryption Key|`from Avere vFXT Management EP - covered in Using the vFXT`|

# Deploy the Avere Controller and VNET

The Avere vFXT controller helps you install and manage an Avere vFXT cluster.

You can deploy the Avere vFXT through the portal, or through the cloud shell.  Before deploying, please review the [vFXT Prerequisites](../../docs/prereqs.md).

## Portal Install

To install from the portal, launch the deployment by clicking the "Deploy to Azure" button:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Favereimageswestus.blob.core.windows.net%2Fgithubcontent%2Fsrc%2Fvfxt%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

Save the output values of the deployment for the vFXT deployment, and capture `location`, `sshString`, and `subnetref` to your tracking table described at the beginning of this document.

## Cloud Shell Install

1. To deploy the controller, first open a cloud shell from the [portal](http://portal.azure.com) or [cloud shell](https://shell.azure.com/).

2. If this is your first time deploying the vFXT, you will need to accept the legal terms.  Change the cloud shell to powershell mode and accept the terms for your subscription by running the following commands updating the **SUBSCRIPTION_ID**:

  ```powershell
  PS C:\> Select-AzureRmSubscription -SubscriptionID #SUBSCRIPTION_ID
  PS C:\> Get-AzureRmMarketplaceTerms -Publisher "microsoft-avere" -Product "vfxt" -Name "avere-vfxt-controller" | Set-AzureRmMarketplaceTerms -Accept
  PS C:\> Get-AzureRmMarketplaceTerms -Publisher "microsoft-avere" -Product "vfxt" -Name "avere-vfxt-node" | Set-AzureRmMarketplaceTerms -Accept
  ```

3. Change the cloud shell back to linux shell, and run the following commands in cloud shell to deploy, updating the commented variables:

  ```bash
  # set the subscription, resource group, and location
  export DstSub=#"SUBSCRIPTION_ID"
  export DstResourceGroupName=#"exampleresourcegroup"
  export DstLocation=#"eastus2"

  # get the Avere vFXT controller template and edit parameters
  curl -o azuredeploy.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/vfxt/azuredeploy.json
  curl -o azuredeploy.parameters.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/vfxt/azuredeploy.parameters.json
  vi azuredeploy.parameters.json

  # deploy the template
  az account set --subscription $DstSub
  az group create --name $DstResourceGroupName --location $DstLocation
  az group deployment create --resource-group $DstResourceGroupName --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
  ```

4. Scroll-up in the deployment output to a section labelled `"outputs"` and save the values for the vFXT deployment, and capture `location`, `sshString`, and `subnetref` to your tracking table described at the beginning of this document.

# Next Steps

Now that you have deployed the controller, here are the next steps:
  1. [Deploy the vFXT cluster](../../docs/jumpstart_deploy.md)
  2. [Access the vFXT cluster](../../docs/access_cluster.md)
  3. [Configure Storage](../../docs/configure_storage.md) - configure cloud storage using your new storage account created in this example.