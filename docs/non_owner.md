# Authorizing non-owners to create clusters
The most straightforward way to create a Microsoft Avere vFXT cluster is to have a subscription owner run the creation script. However, it is possible to work around this requirement by creating an additional access role that gives other users sufficient permissions to install the cluster.
A subscription owner must create the cluster creator role and use it to assign access to the appropriate users.

> NOTE: All of these steps must be taken by a user with owner privileges on the subscription that will be used for the cluster.

1. Copy these lines and save them in a file (for example, `averecreatecluster.json`). Use your subscription ID in the `AssignableScopes` statement.

```
{
	"AssignableScopes": ["/subscriptions/<SUBSCRIPTION_ID>"],
	"Name": "avere-create-cluster",
	"IsCustom": "true"
	"Description": "Can create Avere vFXT clusters",
	"NotActions": [],
	"Actions": [
		"Microsoft.Authorization/*/read",
		"Microsoft.Authorization/roleAssignments/*",
		"Microsoft.Authorization/roleDefinitions/*",
		"Microsoft.Compute/*/read",
		"Microsoft.Compute/availabilitySets/*",
		"Microsoft.Compute/virtualMachines/*",
		"Microsoft.Network/*/read",
		"Microsoft.Network/networkInterfaces/*",
		"Microsoft.Network/routeTables/write",
		"Microsoft.Network/routeTables/delete",
		"Microsoft.Network/routeTables/routes/delete",
		"Microsoft.Network/virtualNetworks/subnets/join/action",
		"Microsoft.Network/virtualNetworks/subnets/read",

		"Microsoft.Resources/subscriptions/resourceGroups/read",
		"Microsoft.Resources/subscriptions/resourceGroups/resources/read",
		"Microsoft.Storage/*/read",
		"Microsoft.Storage/storageAccounts/listKeys/action"
	],
}
```

2. Run this command to create the role:
`az role definition create --role-definition <PATH_TO_FILE>`

   Example:
   `az role definition create --role-definition ./averecreatecluster.json`

3. Assign this role to the user that will create the cluster:
`az role assignment create --assignee <USERNAME> --scope /subscriptions/<SUBSCRIPTION_ID> --role 'avere-create-cluster'`

After this procedure, the user assigned the role will be able to create and configure the network infrastructure, create the cluster controller, and use it to log in and run the template scripts to create the cluster.
