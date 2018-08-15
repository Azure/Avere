# vFXT Prerequisites
There are two prerequisites for vFXT cluster creation.

1. Subscription owner permissions.
1. Quota for the vFXT cluster.

## Subscription owner permissions
The vFXT creation process expects the user to have owner permissions. The controller node must be able to create and modify configuration of the cluster nodes including network security groups and IP addressing.

Users must either be an owner of the subscription or at minimum be an owner of a Resource Group where the Avere controller and cluster will be installed.  

If you need to allow users without any owner privileges to create vFXT clusters, there is a workaround involving creating and assigning an extra access role. This role gives significant extra permissions to these users. Reference [this link](docs/NonOwner.md) for instructions on how to authorize non-owners to create clusters.

## Quota for the vFXT cluster
You must have sufficient quota for the following Azure components.  

[!NOTE]
The Virtual Machines and SSD are for the vFXT cluster itself.  You need additional quota for the VMs and SSD you intend to use for your compute farm.  Get the quota enabled for the region where you intend to run the workflow.

|Azure component|Quota|
|----------|-----------|
|Virtual Machines|3 or more D16s_v3 or E32s_v3|
|Premium SSD Storage|200GB OS and 1-4TB Cache per node|
|Storage Account|v2|
|BLOB|One LRS BLOB Container (optional)|
<!--
|Role|Custom role defined in advance|
|Vnet|One vnet for the Avere cluster|
|Subnet|One Subnet for the Avere cluster|
|Resource Group|One Resource group|
-->
