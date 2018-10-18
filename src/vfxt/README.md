# Avere vFXT cluster controller node - ARM template deployment

This template implements [Deploy](../../docs/jumpstart_deploy.md).

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fvfxt%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

# Experimental: Avere vFXT controller and vFXT - ARM template deployment

An experimental template to deploy everything in one deployment is listed below.  Please try and give feedback.

1. The controller requires login to the az cli with "Owner" role because the script assigns roles.  The following shows how to create the service principal, but detailed instructions are [here](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest):

```bash
SUBSCRIPTION_ID="REPLACE WITH YOUR SUBSCRIPTION ID"
az account set --subscription=$SUBSCRIPTION_ID
az ad sp create-for-rbac --role="Owner" --scopes="/subscriptions/$SUBSCRIPTION_ID"
```

2. Deploy the script using the following "deploy to Azure" button:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fvfxt%2Fazuredeploy-auto.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>