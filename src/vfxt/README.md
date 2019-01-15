# Avere vFXT cluster controller node - ARM template deployment

This template implements [Deploy](../../docs/jumpstart_deploy.md).

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fvfxt%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

# Avere vFXT controller and vFXT - ARM template deployment

The following template deploys the Avere vFXT controller and vFXT in a single deployment.  The deployment will take about 30-40 minutes.  The controller and vFXT use managed identity, and the roles need to be configured correctly in your account prior to proceeding with the deployment.

These instructions are in two steps:
  1. [configure your roles](#managed-identity-and-roles) - this is a one time operation for each subscription
  1. [deploy your vFXT](#deploying-the-vfxt-controller-and-vfxt-cluster) - there are three ways to deploy your vFXT cluster

Once you have deployed your vFXT, proceed to the data ingest of the cluster described in the data ingest article: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-data-ingest.

The construction of this template and packaging for marketplace can be found in the [src](./src) directory.

## Managed Identity and Roles

The Avere vFXT controller and cluster use Azure [managed identities](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview) for deployment and operation.  Additionally the administrator deploying the roles also needs permission to deploy the Avere vFXT controller and cluster.

The following table shows the roles required for each of the avere operations:

   | Name | Description | Role Required |
   | --- | --- | --- |
   | **Controller (vFXT.py)** | the controller uses vFXT.py to create, destroy, and manage a vFXT cluster | "[Avere Contributor](https://github.com/Azure/Avere/blob/master/src/vfxt/src/roles/AvereContributor.txt)" where scoping to the target resource group and vnet resource group is handled by template |
   | **vFXT** | the vFXT manages Azure resources for new vServers, and in response to HA events | "[avere-cluster](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-pre-role)" where scoping to the target resource group and vnet resource group is handled by vFXT.py |
   | **Standalone Administrator** | deploy the VNET, vFXT controller, and vFXT into the same resource group | "[User Access Administrator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#user-access-administrator)" and "[Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor)" scoped to the target vFXT resource group |
   | **Bring your own VNET Administrator**  | deploy vFXT controller, and vFXT into the same resource group but reference the VNET from a different resource group | "[User Access Administrator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#user-access-administrator)" and "[Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor)" scoped to the target vFXT resource Group, and "[Virtual Machine Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#virtual-machine-contributor)" and "[Avere Contributor](https://github.com/Azure/Avere/blob/master/src/vfxt/src/roles/AvereContributor.txt)" scoped to the VNET resource group|

Here are the instructions to create custom Avere Roles:
  1. "avere-cluster" - use instructions from [the Avere documention for runtime role creation](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-pre-role).  Microsoft employees should specify already defined role "Avere Cluster Runtime Operator".
  1. "Avere Contributor" - apply the ["Avere Contributor" role file](src/roles/AvereContributor.txt), using instructions from [the Avere documentation for runtime role creation](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-pre-role).  Microsoft employees should specify already defined roleName "Avere Cluster Create" with roleId  "a7b1b19a-0e83-4fe5-935c-faaefbfd18c3".

After creating the contributor role, you will need to get the role ID to pass to template (Microsoft employees use roleId "a7b1b19a-0e83-4fe5-935c-faaefbfd18c3").  The AAD role id is a GUID used for creating of the vFXT cluster.  This is the ID obtained using the following az command: az role definition list --query '[*].{roleName:roleName, name:name}' -o table --name 'Avere Contributor'.  Currently the template defaults to the [Owner role](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) with GUID 8e3af657-a8ff-443c-a75c-2fe8c4bcb635.

There are two deployment modes of the Avere vFXT: standalone and "bring your own VNET".  In the standalone case, the deployment deploys the controller and vFXT cluster into a brand new VNET.  In the "bring your own VNET" deployment, the controller and vFXT cluster uses ip addresses from an existing vnet subnet.  Both of these cases require different role configurations.  The following two sections highlight show the strictest scoping to a service principal, but these can be generalized to any user principal.

### Example: Create Service principal for Standalone Administrator

A standalone administrator deploys the controller and vFXT cluster into a brand new VNET all within the same resource group.

Here are the CLI instructions that can be used from the [Azure Cloud Shell](http://shell.azure.com) to create a service principal with the strictest possible scope for a standalone administrator.  This assumes you have ownership rights to the subscription:

```bash
export SUBSCRIPTION=#YOUR SUBSCRIPTION
export VFXT_RESOURCE_GROUP=#the target VFXT resource group
export TARGET_LOCATION=#the resource group location
az account set --subscription $SUBSCRIPTION
az group create --location $TARGET_LOCATION --name $VFXT_RESOURCE_GROUP
# create the SP
az ad sp create-for-rbac --role "Contributor" --scopes /subscriptions/$SUBSCRIPTION/resourceGroups/$VFXT_RESOURCE_GROUP
# save the output somewhere safe
export SP_APP_ID=#the appId of the Service Principal from the previous command
az role assignment create --role "User Access Administrator" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/$VFXT_RESOURCE_GROUP --assignee $SP_APP_ID
###########################################################
# pass the SP details to the person installing the vFXT
# once complete, delete the SP with the following command:
#    az ad sp delete --id $SP_APP_ID
###########################################################
```

### Example: Create Service principal for Bring your own VNET Administrator

A Bring your own VNET Administrator deploys the controller and vFXT cluster into a resource group referencing a VNET from another resource group.

Here are the CLI instructions that can be used from the [Azure Cloud Shell](http://shell.azure.com) to create a service principal with the strictest possible scope for a Bring your own VNET administrator.  This assumes you have ownership rights to the subscription:

```bash
export SUBSCRIPTION=#YOUR SUBSCRIPTION
export VFXT_RESOURCE_GROUP=#the target VFXT resource group
export TARGET_LOCATION=#the resource group location
export VNET_RESOURCE_GROUP=#the target VNET resource group
az account set --subscription $SUBSCRIPTION
az group create --location $TARGET_LOCATION --name $VFXT_RESOURCE_GROUP
# create the SP
az ad sp create-for-rbac --role "Contributor" --scopes /subscriptions/$SUBSCRIPTION/resourceGroups/$VFXT_RESOURCE_GROUP
# save the output somewhere safe
export SP_APP_ID=#the appId of the Service Principal from the previous command
az role assignment create --role "User Access Administrator" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/$VFXT_RESOURCE_GROUP --assignee $SP_APP_ID
# assign the "Virtual Machine Contributor" and the "Avere Contributor" to the scope of the VNET resource group
az role assignment create --role "Virtual Machine Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/$VNET_RESOURCE_GROUP --assignee $SP_APP_ID
az role assignment create --role "Avere Cluster Create" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/$VNET_RESOURCE_GROUP --assignee $SP_APP_ID
###########################################################
# pass the SP details to the person installing the vFXT
# once complete, delete the SP with the following command:
#    az ad sp delete --id $SP_APP_ID
###########################################################
```

## Deploying the vFXT controller and vFXT cluster

There are three ways to deploy the vFXT cluster.  In each of the methods you will need to have the minimum required role access described in the previous section.

   | Deployment Method | Details | URL |
   | --- | --- | --- |
   | **Portal Wizard** | the portal Wizard walks you through the creation of the controller and vFXT.  This is private preview, so please post github issue if you would like access | [wizard](https://portal.azure.com/?pub_source=email&pub_status=success#create/microsoft-avere.vfxt-template-previewavere-vfxt-arm) |
   | **Portal Template** | this uses the default portal template wizard and requires care when entering fields  | <a href="https://portal.azure.com/?pub_source=email&pub_status=success#create/microsoft-avere.vfxt-template-previewavere-vfxt-arm" target="_blank"><img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/></a> |
   | **Azure CLI** | the template can be automated using CLI or SDK | See the [example below](#example-using-cli-to-deploy-the-cluster). |

After the deployment completed, check the template output for some important information like management ip address and vserver ip address range.

Once you have deployed your vFXT, proceed to the data ingest of the cluster described in the data ingest article: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-data-ingest.

### Example: using CLI to deploy the cluster

This example assumes you are using a service principal created from the previous section.  You may also use this from the [Azure Cloud Shell](http://shell.azure.com) but avoid the login step if your account has enough permissions.

```bash
export SUBSCRIPTION=#YOUR SUBSCRIPTION
export VFXT_RESOURCE_GROUP=#the target VFXT resource group
###############################
# only login if you do not have enough permissions, or want to use service principal created from previous step
export AZURE_CLIENT_ID=#use service principal appId
export AZURE_CLIENT_SECRET=#use service principal password
export AZURE_TENANT_ID=#use service principal tenant
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
###############################
az account set --subscription $SUBSCRIPTION
curl -o azuredeploy-auto.json https://raw.githubusercontent.com/Azure/Avere/master/src/vfxt/azuredeploy-auto.json
export STANDALONE_PARAMETERS_URL=https://raw.githubusercontent.com/Azure/Avere/master/src/vfxt/azuredeploy-auto.parameters.new.vnet.json
export BYOVNET_PARAMETERS_URL=https://raw.githubusercontent.com/Azure/Avere/master/src/vfxt/azuredeploy-auto.parameters.use.existingvnet.json
export PARAMETERS_URL=# depending on your install requirements, choose either $STANDALONE_PARAMETERS_URL or $BYOVNET_PARAMETERS_URL
curl -o azuredeploy-auto.parameters.json $PARAMETERS_URL
# edit the parameters with your unique values
vi azuredeploy-auto.parameters.json
# deploy the template
az group deployment create --resource-group VFXT_RESOURCE_GROUP --template-file azuredeploy-auto.json --parameters @azuredeploy-auto.parameters.json
```

After the deployment completed, check the template output for some important information like management ip address and vserver ip address range.

Once you have deployed your vFXT, proceed to the data ingest of the cluster described in the data ingest article: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-data-ingest.