# Create a scoped service principal

The following script will create a scoped service principal.  Once you fill in the exports, this can be run from Azure Cloud Shell: https://shell.azure.com.

```bash
#!/bin/bash

set -x

export SUBSCRIPTION=
export VFXT_RESOURCE_GROUP=
export TARGET_LOCATION=eastus
export VNET_RESOURCE_GROUP=
az account set --subscription $SUBSCRIPTION

# create the RG if not already created
az group create -l $TARGET_LOCATION -n $VFXT_RESOURCE_GROUP
az group create -l $TARGET_LOCATION -n $VNET_RESOURCE_GROUP

# create the SP
az ad sp create-for-rbac --skip-assignment | tee sp.txt
echo '!!!! Save the above somewhere safe !!!!'
export SP_APP_ID=$(jq -r '.appId' sp.txt)
export SP_APP_ID_SECRET=$(jq -r '.password' sp.txt)
export SP_APP_ID_TENANT=$(jq -r '.tenant' sp.txt)
rm sp.txt

# the following function will retry on failures due to propagation delays
function create_role_assignment() {
    retries=12; sleep_seconds=10
    role=$1; scope=$2; assignee=$3
    for i in $(seq 1 $retries); do
        az role assignment create --role "${role}" --scope $scope --assignee $assignee
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"az role assignment create --role \"${role}\" --scope $scope --assignee $assignee\" $i times;
            return 1
        else
            sleep $sleep_seconds
        fi
    done
}

# all resource groups must previously exist
create_role_assignment "Avere Contributor" /subscriptions/$SUBSCRIPTION/resourceGroups/$VFXT_RESOURCE_GROUP $SP_APP_ID
create_role_assignment "User Access Administrator" /subscriptions/$SUBSCRIPTION/resourceGroups/$VFXT_RESOURCE_GROUP $SP_APP_ID
# assign the "Virtual Machine Contributor" and the "Avere Contributor" to the scope of the VNET resource group
create_role_assignment "Virtual Machine Contributor" /subscriptions/$SUBSCRIPTION/resourceGroups/$VNET_RESOURCE_GROUP $SP_APP_ID
create_role_assignment "Avere Contributor" /subscriptions/$SUBSCRIPTION/resourceGroups/$VNET_RESOURCE_GROUP $SP_APP_ID
create_role_assignment "User Access Administrator" /subscriptions/$SUBSCRIPTION/resourceGroups/$VNET_RESOURCE_GROUP $SP_APP_ID

echo "// ###################################################
// please save the following for terraform local vars
// ###################################################

    subscription_id = \"${SUBSCRIPTION}\"
    client_id       = \"${SP_APP_ID}\"
    client_secret   = \"${SP_APP_ID_SECRET}\"
    tenant_id       = \"${SP_APP_ID_TENANT}\"

    controller_managed_identity_id = \"${controllerMI_ARMID}\"
    vfxt_managed_identity_id = \"${vfxtmi_ARMID}\""

# clear the secret
export SP_APP_ID_SECRET=""