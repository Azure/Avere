# HPC Cache Private Preview documentation (draft version 2019-07-03)  

This page provides partial documentation for the Azure HPC Cache private preview. 

Information is subject to change - please verify this information with your Microsoft Service and Support representative before using it in a production environment or in a high-value test.

## Getting started

Before using the Azure Portal to create a new HPC Cache, check these prerequisites. 

* Your subscription must be whitelisted for the private preview program. Your HPC Cache representative can assist you with the request. 
* During the preview period, you need to add the Storage Account Contributor role to the storage account used for the HPC Cache instance. Details are [below](#add-the-access-control-role-to-your-account).  
* If you want to use Azure Blob storage with the HPC Cache, create a new empty Blob container before starting to create the cache instance. (You can add storage after you create the HPC Cache if you don't do this before.) 

 


## Creating a cache 

### Cache sizing 

### Adding storage targets 

Storage targets are the long-term storage for the contents of your cache. 

#### Add the access control role to your account

During the private preview, the HPC Cache uses [role-based access control (RBAC)](https://docs.microsoft.com/azure/role-based-access-control/index) to authorize the HPC Cache application to access your storage account. The storage account owner must explicitly add the role [Storage Account Contributor](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor) for the user "StorageCache Resource Provider". 

You can do this when you add the storage target as part of creating the HPC Cache instance. Links are provided in the storage target section of the creation wizard.

Steps to add the RBAC role: 

1. Open the **Access control (IAM)** page for the storage account.
1. Click the **+** at the top of the page and choose **Add a role assignment**.
1. Select the role "Storage Account Contributor" from the list.
1. In the **Assign access to** field, leave the default value selected ("Azure AD user, group, or service principal").  
1. In the **Select** field, search for "storagecache". This should match one security principal, named HPC Cache Resource Provider. Click that principal to select it. 
1. Click the **Save** button to add the role assignment to the storage account. 

![screenshot of add role assignment GUI](add-role.png)

#### Using the aggregated namespace 

The HPC Cache allows clients to access a variety of storage systems through a virtual namespace that hides the details of the back-end storage system. 

When you add a storage target, you set the client-facing filepath. Client machines mount this filepath. You can change the storage target associated with that path, for example to replace a hardware storage system with cloud storage, without needing to rewrite client-facing procedures. 


### Choose a usage model 

When you create a storage target, you need to choose the *usage model* for that target. This model determines how your data is cached. 


## Additional information

Details about the Azure HPC Cache will be available in late summer 2019. 

### Terms of service

This product is in Private Preview. Terms of Service will be made available in Public Preview or General Availability phases.

### Pricing

This product is in Private Preview. Pricing information will be made available in Public Preview or General Availability phases.
