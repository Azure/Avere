# Creating an Azure storage account as a core filer

To use Azure Blob storage as your vFXT cluster's back-end storage, you need an empty container to add as a cluster core filer.

If you did not create an Azure storage account as part of creating your vFXT cluster, you can create a storage container later. The storage container must be from the same subscription as the vFXT cluster.

**TIP:** Use the ``create-cloudbacked-cluster`` sample script if you want to create a storage container at the same time as creating the vFXT cluster. The ``create-minimal-cluster`` sample script does not create an Azure storage container. 

In the Azure portal, click **All services** and select the **Storage accounts** category. 

Follow the [Azure documentation](<https://docs.microsoft.com/en-us/azure/storage/common/storage-quickstart-create-account?tabs=portal>) to create a general-purpose V2 storage account and create a container. 

After creating the container, follow the instructions in [Create a core filer](configure_storage.md#create-a-core-filer) to add it to the cluster. 