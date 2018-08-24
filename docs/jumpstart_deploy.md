# Deploy a vFXT Cluster
The easiest way to create a vFXT cluster, is to use a controller node which has scripts and templates for creating the vFXT cluster. In this tutorial, you will create a controller node and use it to create a vFXT cluster.  By the end of this tutorial, you will have a VNET, a controller, and a vFXT cluster as shown in the following diagram:

<img src="images/vfxt_deployment.png">

This tutorial assumes that you have done the following prerequisites:

1. [Create a new subscription](prereqs.md#create-a-new-subscription)
1. [Subscription owner permissions](prereqs.md#subscription-owner-permissions).
1. [Quota for the vFXT cluster](prereqs.md#quota-for-the-vfxt-cluster).
1. [Accepting the Legal Terms for the marketplace images](prereqs.md#accepting-the-legal-terms-for-the-two-marketplace-images).
1. [Create an Azure RBAC Role](prereqs.md#create-an-azure-rbac-role)

## Create Controller

To install from the portal, launch the deployment by clicking the "Deploy to Azure" button:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Favereimageswestus.blob.core.windows.net%2Fgithubcontent%2Fsrc%2Fvfxt%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

Add a name for the new resource group, update the controller name and password, and click "Purchase".  After 5 or 6 minutes, your controller node will be up and running.

## Browse to outputs

The outputs have the information you need to deploy your Avere vFXT cluster.

1. From the notification icon on the top bar, click "Go to resource group", and this will show the new resource group that contains your controller and VNET.

   <img src="images/browse_to_resource_group.png">

2. On left side, click "deployments", and "Microsoft.Template"

   <img src="images/deployment_template.png">

3. On left side, click "outputs", and copy the values in each of the fields for creating your controller.

   <img src="images/template_outputs.png">

## Create cluster
Now that your controller node is running, you need to access the controller node, edit the templates, and run the create cluster script. 

### Access the cluster

1. SSH to the controller using the `SSHSTRING` you captured in the [outputs above](browse-to-outputs).

2. Authenticate by running `az login`.  In this step, browse to https://microsoft.com/devicelogin in any web browser, put in the unique code, authenticate to Microsoft, and then return to the shell.

   <img src="images/9azlogin.png">

3. Run ```az account set --subscription YOUR_SUBSCRIPTION_ID```

### Edit the deployment template

Copy and then edit the `create-minimal-cluster` template. For example:
```sh
cp /create-minimal-cluster ./cmc
vi cmc
```

In the file cmc, edit the following fields you captured in [outputs above](browse-to-outputs): resource group, location, virtual network, and subnet:

```bash
RESOURCE_GROUP=<from the Outputs>
LOCATION=<from the Outputs>
NETWORK=<from the Outputs>
SUBNET=<from the Outputs>
```

Additionally add name of the cluster role name you just created, and add an admin password:

```bash
AVERE_CLUSTER_ROLE=<name of role created above (avere-cluster)>
ADMIN_PASSWORD=<your unique vfxt cluster password>
```

Save the file and exit.

### Run the script
Run the script by typing `./cmc &`.  The script is put into the background in case you lose your connection.  You can always look for the log output in ~/vfxt.log.

When the script completes, copy the management IP address.

<img src="images/14mgmtip.png">

### Proceed to Accessing the Cluster
Now that the cluster is running, and you have the management IP address, you can now [click here to access the cluster](https://github.com/Azure/Avere/blob/master/docs/access_cluster.md).
