# NFS NAS Core Filer for LSv1

The templates in this folder implements an NFS based NAS Filer using the LSv1 series SKU on Azure as described on the LS-Series page: https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sizes-previous-gen#ls-series.

The pre-requisites for this template are the following:
1. an SSH public key,
2. a VNET already created

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Ftutorials%2Fnfsfiler-LSv1%2Fnfs-azuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

The template can also be deployed through the az cli using the following steps:

1. open https://shell.azure.com

2. set the correct subscription, replacing your azure subscription id with `AZURE_SUBSCRIPTION_ID`:

```bash
az account set --subscription AZURE_SUBSCRIPTION_ID
```

3. download the templates

```bash
curl -o nfs-azuredeploy.parameters.json https://raw.githubusercontent.com/Azure/Avere/master/src/tutorials/nfsfiler-LSv1/nfs-azuredeploy.parameters.json
curl -o nfs-azuredeploy.json https://raw.githubusercontent.com/Azure/Avere/master/src/tutorials/nfsfiler-LSv1/nfs-azuredeploy.json
```
4. edit the parameters, and set the correct values

```bash
export DstResourceGroupName="nfsfiler1"
export DstLocation="uksouth"
az group create --name $DstResourceGroupName --location $DstLocation
az group deployment create --resource-group $DstResourceGroupName --template-file nfs-azuredeploy.json --parameters @nfs-azuredeploy.parameters.json
```

5. deploy the template, and capture the output variables to get the IP address, and exported path.
