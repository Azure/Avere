# Template Naming Standards

## Template patterns

Here are the common patterns:
* parameters converted to variables at the top of variables section, and used as variables for the rest of the section.
    * special note: Azure batch job scripts do not allow this conversion.
* outputs show data to be used for later inputs into other templates

## Parts directory

Some of the template solutions are generated from multiple parts.  Python 2.7 is used to generate the templates.  To build, run the python script with no arguments from the directory of the python script.

## Parameter Naming

| Parameter | Sample Description |
| --- | --- |
| adminUsername | The vm admin username. |
| adminPassword | The vm admin password. |
| avereVServerBootstrapAddress | One of the Avere vFXT vServer NFS IP addresses. |
| avereManagementAddress | The IP address of the Avere vFXT Management UI. |
| avereNamespacePath | The Avere vFXT namespace path. |
| avereVServerCommaSeparatedAddresses | A comma separated list of Avere vFXT vServer IP Addresses. |
| avereVServerAddress | One of the Avere vFXT vServer NFS IP addresses. |
| centOSBootstrapScriptPath | The path of the centos bootstrap script. |
| maxTasksPerNode | The number of tasks per node |
| poolId | The id of the Azure Batch pool, this can be any unique name. |
| sshKeyData | |
| subnetId | The fully qualified reference to the subnet of the Avere vFXT cluster.  Example /subscriptions/SUBSCRIPTION/resourceGroups/RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/NETWORK_NAME/subnets/SUBNET_NAME. |
| targetBatchVMSize | The size of the virtual machines that run the jobs. |
| targetDedicatedNodeCount | The number of dedicated virtual machines in the Azure Batch pool. |
| targetLowPriorityNodeCount | The number of low priority virtual machines in the Azure Batch pool where the job will run. |
| uniquename | The unique name used for resource names associated with the controller |
| vmSize | Size of the VM. |

## Output Naming

| Output Variable Name |
| --- | 
| CLIENT_RDP_ADDRESS |
| LOCATION |
| NETWORK |
| SUBNET |
| SUBNET_ID |
| RESOURCE_GROUP |
| SSH_STRING |
