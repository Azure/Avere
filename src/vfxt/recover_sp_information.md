# How to recover Service Principal Information

The following Service Principal information is required in order to deploy Avere vFXT using this template solution, Service Principal Tenant Id, App Id and password, please execute the following steps in CloudShell (https://shell.azure.com) to recover it.

1. If you don't know the exact name, **az ad sp create-for-rbac** command creates the service principal with its displayName starting with **azure-cli**, in this case you can first obtain the list of service principals and then select one from the output list, if you already know the full displayName, skip to step 2.
```bash
DISPLAY_NAME_START='azure-cli'
az ad sp list --filter "startswith(displayName,'$DISPLAY_NAME_START')" --query '[].{displayName:displayName,appDisplayName:appDisplayName, objectId:objectId,appId:appId,appOwnerTenantId:appOwnerTenantId}' -o table
```
2. If you know the exact displayName you can use this commandLine (make sure you change the variable content in the first line)
```bash
DISPLAY_NAME='azure-cli-2018-10-31-19-56-28'
az ad sp list --filter "displayName eq '$DISPLAY_NAME'" --query '[].{displayName:displayName,appDisplayName:appDisplayName, objectId:objectId,appId:appId,appOwnerTenantId:appOwnerTenantId}' -o table
```

3. Either commands will output all needed information with exception of the password as follows:

```bash
DisplayName                    AppDisplayName                 ObjectId                              AppId                                 AppOwnerTenantId
-----------------------------  -----------------------------  ------------------------------------  ------------------------------------  ------------------------------------
azure-cli-2018-10-31-19-56-28  azure-cli-2018-10-31-19-56-28  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx   aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa  bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb
```

4. Add a new password to the service principal, make sure that the value of **--name** is the same as the **AppDisplayName** from the output you obtained from the above queries (password will be appended to the Application associated to the Service Principal and it may or may not match the DisplayName).

```bash
az ad sp credential reset --name azure-cli-2018-10-31-19-56-28 --append
```

5. The following output is all you need to continue your deployment (notice that with exception of the password, the values matches your previous query results):
```bash
{
  "appId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "name": "azure-cli-2018-10-31-19-56-28",
  "password": "dddddddd-dddd-dddd-dddd-dddddddddddd",
  "tenant": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb"
}
```