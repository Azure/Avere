# Avere vFXT using User Assigned Managed Identity

This examples configures a controller and vfxt with a user assigned managed identity.  The example also creates a render network, an nfs filer and an Azure Blob Storage cloud core filer as shown in the diagram below:

![The architecture](../../../../../docs/images/terraform/userassignedmi.png)

## Deployment Instructions

This example has the following steps:

1. Setup the Prerequisites
1. Create the service principal to use with terraform, and the managed identities for use by the controller and vfxt
1. Deploy the VNET, filer, storage accounts, controller, and vfxt
1. Cleanup the resources and service principal

### Setup the Prerequisites

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell, but you can use in your own environment.  If you do use your own environment, you will need to install the vfxt provider as described in the [build provider instructions](../../../providers/terraform-provider-avere#build-the-terraform-provider-binary) and follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. double check your Avere vFXT prerequisites, including running `az vm image accept-terms --urn microsoft-avere:vfxt:avere-vfxt-controller:latest`: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs

4. If not already installed, run the following commands to install the Avere vFXT provider for Azure:
```bash
mkdir -p ~/.terraform.d/plugins
# install the vfxt released binary from https://github.com/Azure/Avere
wget -O ~/.terraform.d/plugins/terraform-provider-avere https://github.com/Azure/Avere/releases/download/tfprovider_v0.9.12/terraform-provider-avere
chmod 755 ~/.terraform.d/plugins/terraform-provider-avere
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

### Create the Resource Groups, Service Principal, and Managed Identities

This step will create the resource groups, service principal, and the managed identities for use with the terraform deployment.  The service principal will be correctly scoped to the resource groups with restricted roles as described in the [Managed Identities Section of the Avere provider](../../../providers/terraform-provider-avere#managed-identities).

This assumes you have the `Owner` role.  If not have someone with the `Owner` role run the following commands.  Ensure you save the output, as this will be needed in the terraform and for cleanup.

```bash
# update the variables with your own variables
export LOCATION=eastus
export RG_PREFIX=aaa_ # this can be blank, it is used to group the resource groups together
export SUBSCRIPTION=00000000-0000-0000-0000-000000000000 #YOUR SUBSCRIPTION

# create the resource groups
az group create --location $LOCATION --resource-group ${RG_PREFIX}managed_identity
az group create --location $LOCATION --resource-group ${RG_PREFIX}network_resource_group
az group create --location $LOCATION --resource-group ${RG_PREFIX}storage_resource_group
az group create --location $LOCATION --resource-group ${RG_PREFIX}vfxt_resource_group

# create the service principal
az ad sp create-for-rbac --skip-assignment | tee sp.txt
echo '!!!! Save the above somewhere safe !!!!'
export SP_APP_ID=$(jq -r '.appId' sp.txt)
export SP_APP_ID_SECRET=$(jq -r '.password' sp.txt)
export SP_APP_ID_TENANT=$(jq -r '.tenant' sp.txt)
rm sp.txt

# assign the "Managed Identity Operator"
# retry on first role assignment to allow the appId to propagate
while true; do az role assignment create --role "Managed Identity Operator" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}managed_identity --assignee $SP_APP_ID; [ $? -eq 0  ] && break; sleep 10; done
az role assignment create --role "Managed Identity Operator" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}vfxt_resource_group --assignee $SP_APP_ID

# assign the "Network Contributor"
az role assignment create --role "Network Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}network_resource_group --assignee $SP_APP_ID

# assign the "Storage Account Contributor" for storage accounts and "Virtual Machine Contributor" for NFS Filers
az role assignment create --role "Storage Account Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}storage_resource_group --assignee $SP_APP_ID
az role assignment create --role "Virtual Machine Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}storage_resource_group --assignee $SP_APP_ID

# assign the "Avere Contributor"
az role assignment create --role "Avere Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}vfxt_resource_group --assignee $SP_APP_ID
az role assignment create --role "Virtual Machine Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}vfxt_resource_group --assignee $SP_APP_ID
az role assignment create --role "Network Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}vfxt_resource_group --assignee $SP_APP_ID

# create the controller managed identity
az identity create --resource-group ${RG_PREFIX}managed_identity --name controllermi | tee cmi.txt
export controllerMI_ID=$(jq -r '.clientId' cmi.txt)
rm cmi.txt
# retry on first role assignment to allow the appId to propagate
while true; do az role assignment create --role "Avere Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}vfxt_resource_group --assignee $controllerMI_ID ; [ $? -eq 0  ] && break; sleep 10; done
az role assignment create --role "Avere Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}network_resource_group --assignee $controllerMI_ID 
az role assignment create --role "Avere Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}storage_resource_group --assignee $controllerMI_ID 
az role assignment create --role "Managed Identity Operator" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}vfxt_resource_group --assignee $controllerMI_ID 
az role assignment create --role "Managed Identity Operator" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}managed_identity --assignee $controllerMI_ID 

# create the vfxt managed identity
az identity create --resource-group ${RG_PREFIX}managed_identity --name vfxtmi | tee vfxtmi.txt
export vfxtmi_ID=$(jq -r '.clientId' vfxtmi.txt)
rm vfxtmi.txt
# retry on first role assignment to allow the appId to propagate
while true; do az role assignment create --role "Avere Operator" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}vfxt_resource_group --assignee $vfxtmi_ID ; [ $? -eq 0  ] && break; sleep 10; done
az role assignment create --role "Avere Operator" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}network_resource_group --assignee $vfxtmi_ID 
az role assignment create --role "Avere Operator" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/${RG_PREFIX}storage_resource_group --assignee $vfxtmi_ID 

echo "// ###############################################"
echo "// please save the following for terraform locals"
echo "// ###############################################"
echo ""
echo "    subscription_id = \"${SUBSCRIPTION}\""
echo "    client_id       = \"${SP_APP_ID}\""
echo "    client_secret   = \"${SP_APP_ID_SECRET}\""
echo "    tenant_id       = \"${SP_APP_ID_TENANT}\""
echo ""    
echo "    controller_managed_identity_id = \"${controllerMI_ID}\""
echo "    vfxt_managed_identity_id = \"${vfxtmi_ID}\""

# clear the secret
export SP_APP_ID_SECRET=""
```

### Deploy the Example

This step will deploy the VNET, filer, storage account, controller and vfxt.  It will use the service principal and managed identities created above.

1. `cd ~/tf/src/terraform/examples/vfxt/user-assigned-managed-identity`

2. `code main.tf` to edit the local variables section at the top of the file and to customize to your preferences.  At the top paste in the variables from the output of the principal script executed above.  If you are using an [ssk key](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys), ensure that ~/.ssh/id_rsa is populated.

3. execute `terraform init` in the directory of `main.tf`.

4. execute `terraform apply -auto-approve` to build the vfxt cluster

Once installed you will be able to login and use the vFXT cluster according to the vFXT documentation: https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-cluster-gui.

Try to scale up and down the cluster, adjust the customer settings, add new junctions, etc, by editing the `main.tf`, and running `terraform apply -auto-approve`.

### Cleanup the resources and service principal

Once you have finished testing, run the following commands to cleanup the resources, and service principals:

1. `terraform destroy -auto-approve`
1. delete the service principal
```bash
export SP_APP_ID= # your appId
az ad sp delete --id $SP_APP_ID
```
1. delete the resource groups
```bash
export RG_PREFIX=aaa_
az group delete --yes --resource-group ${RG_PREFIX}managed_identity
az group delete --yes --resource-group ${RG_PREFIX}network_resource_group
az group delete --yes --resource-group ${RG_PREFIX}storage_resource_group
az group delete --yes --resource-group ${RG_PREFIX}vfxt_resource_group
```
