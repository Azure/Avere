# Troubleshooting and engaging support

If you encounter problems or need help with your Avere vFXTX for Azure, here are the various ways to get help:

  * **Avere vFXT issue** - Raise a support ticket in the Azure Portal for your Avere vFXT as described in the [section below](#raise-a-support-ticket-for-your-avere-vfxt)
  * **Quota** - If you encounter a quota-related issue, [request a quota increase](https://docs.microsoft.com/en-us/azure/azure-supportability/resource-manager-core-quotas-request).
  * **Documentation and examples** - If you find issues with the examples in this Avere documentation, please check for it in this repository's [issues](https://github.com/Azure/Avere/issues) list. If your problem isn't listed, file a [github issue](https://github.com/Azure/Avere/issues).

# Raise a support ticket for your Avere vFXT

If you encounter issues with the Avere vFXT, you can request help through the Azure portal.  

Follow these steps to make sure that your support ticket is tagged with a resource from your cluster, which will expedite ticket routing:

1. From https://portal.azure.com, select **Resource Groups**.

    <img src="images/portal-resourcegroups.png">

2. Browse to the resource group that contains the vFXT cluster where the issue occurred, and click on one of the Avere virtual machines.

    <img src="images/portal-choosevm.png" width="750">

3. Scroll down in the left panel of VM options and click **New support request** at the bottom.

    <img src="images/portal-newsupportrequest.png" width="750">

4. On page 1, click **All Services** and look under **Storage** to choose **Avere vFXT**

    <img src="images/portal-averevfxt.png" width="750">

5. On page 2, choose the problem type and category that most closely matches your issue.  Add a short title and description that includes the time the issue occurred. 

    <img src="images/portal-problemdescription.png" width="750">

6. On page 3, fill in your contact information, and click **Create**.  You will receive a ticket number by email, and a support staff member will contact you. 
