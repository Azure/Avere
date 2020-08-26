# Avere vFXT prerequisites

These tasks are prerequisites for creating an Avere vFXT cluster.

1. [Create a new subscription](#create-a-new-subscription)
1. [Configure subscription owner permissions](#subscription-owner-permissions)
1. [Check quota for the vFXT cluster](#quota-for-the-vfxt-cluster)
1. [Accept the terms for the marketplace images](#accepting-terms-for-the-two-marketplace-images)
1. [Create an Azure RBAC role](#create-an-azure-rbac-role)

**Tip:** If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.

## Create a new subscription

Start by creating a new subscription to track all project resources and expenses. Having a separate subscription for each Avere vFXT project lets you easily track all project resources and expenses, and simplifies cleanup.  

To create a new Azure subscription: 

- Navigate to the [Subscriptions blade](https://ms.portal.azure.com/#blade/Microsoft_Azure_Billing/SubscriptionsBlade)
- Click the **+ Add** button at the top
- Sign in if prompted
- Select an offer and walk through the steps for a new subscription

## Subscription owner permissions

The vFXT cluster creation process expects the user to have supscription owner permissions. The cluster controller node must be able to create and modify the cluster nodes, including configuring network security groups and IP addressing.

To create the cluster, the user must either be an owner of the subscription, or at minimum be an owner of the resource group where the Avere controller and all cluster resources will be installed. 

If you need to allow users without any owner privileges to create vFXT clusters, there is a workaround involving creating and assigning an extra access role. This role gives significant extra permissions to these users. Reference [this link](non_owner.md) for instructions on how to authorize non-owners to create clusters.

## Quota for the vFXT cluster
You must have sufficient quota for the following Azure components. Here are the steps to [request quota increase](https://docs.microsoft.com/en-us/azure/azure-supportability/resource-manager-core-quotas-request).

**NOTE:** The virtual machines and SSD components listed here are for the vFXT cluster itself. You will need additional quota for the VMs and SSD you intend to use for your compute farm.  Make sure the quota is enabled for the region where you intend to run the workflow.

|Azure component|Quota|
|----------|-----------|
|Virtual machines|3 or more E32s_v3|
|Premium SSD storage|200GB OS and 1-4TB Cache per node|
|Storage account (optional) |v2|
|Data backend storage (optional) |One LRS Blob container |

## Accepting terms for the two marketplace images

Before you can deploy the Avere vFXT cluster, you must accept the legal terms for the Marketplace images. There are two images used in vFXT cluster creation, and you must accept terms for both of them.  

Terms are accepted at the subscription level, so you will need to do this once for each subscription you will use to deploy an Avere vFXT.

You can use the [cloud shell](#cloud-shell) or the [Azure portal](#azure-portal) to accept the legal terms for the marketplace images.



### Cloud Shell

1. Browse to https://shell.azure.com

2. Change the mode to PowerShell by using the shell selector drop down at the top left of the window.

   <img src="images/cloud_shell_powershell.png">

3. Type in the following commands for each subscription you will use to deploy the Avere vFXT:

   ```powershell
   Select-AzureRmSubscription -SubscriptionID <your-Azure-subscription-id>

   Get-AzureRmMarketplaceTerms -Publisher "microsoft-avere" -Product "vfxt" -Name "avere-vfxt-controller" | Set-AzureRmMarketplaceTerms -Accept

   Get-AzureRmMarketplaceTerms -Publisher "microsoft-avere" -Product "vfxt" -Name "avere-vfxt-node" | Set-AzureRmMarketplaceTerms -Accept
   ```
   
### Azure Portal

1. Find the Avere images by navigating to the [Azure marketplace](https://ms.portal.azure.com/#blade/Microsoft_Azure_Marketplace/GalleryFeaturedMenuItemBlade/selectedMenuItemId/home) and searching for ``Avere``.

2. Click one of the images and select the link to enable programmatic access. This link appears at the bottom of the image details, below the **Create** button.  

   <!-- ![Screenshot of a link to programmatic access which is below the Create button](images/2-prog-access-link.png) -->
   
3. Click the button to enable access for your subscription. You’ll only need to do this once for each subscription. Save the setting. 

   <!-- ![Screenshot showing mouse click to enable programmatic access](images/3-enable-prog-access.png) -->

4. Repeat steps 2 and 3 for the other image. 

## Create an Azure RBAC role

Create a role-based access control role for the vFXT cluster nodes. 

The Avere vFXT cluster uses managed service identity (MSI) for normal cluster operations, including reading Azure resource properties and controlling the cluster nodes' network interface resources to support high availability and node failover. This  role is used for the vFXT cluster nodes only, not for the controller VM.

1. Open the cloud shell in the Azure portal or browse to https://shell.azure.com.

2. Run ```az account set --subscription YOUR_SUBSCRIPTION_ID```

3. Use these commands to download the role definition and paste in your subscription ID. 

```bash
wget -O- https://averedistribution.blob.core.windows.net/public/vfxtdistdoc.tgz | tar zxf - avere-cluster.json
vi avere-cluster.json
```

4. Edit the file to include your subscription ID. Save the file as ``avere-cluster.json``. 

<!-- ![Console text editor showing the subscription ID and the "remove this line" selected for deletion](images/edit_role.png) -->

5. Create the role:  

```bash
az role definition create --role-definition /avere-cluster.json
```
