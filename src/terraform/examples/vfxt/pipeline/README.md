# Building a Pipeline for the vFXT Provider

These instructions help customers deploy their vFXT as part of a devops pipeline or to be used in a [GitOps Pipeline as outlined by Rick Shahid](https://techcommunity.microsoft.com/t5/azure-storage/gitops-for-azure-rendering/ba-p/1326920).

## Prerequisites

To run this example, ensure that you have created a service principal:

1. open Azure Cloud Shell: https://shell.azure.com

1. Run the following command to create the service principal, and save the values in Azure Key Vault or somewhere safe.  If you need a more refined set of roles and role assignements, please review [creating a vfxt scoped service principal](createscopedsp.md).

```bash
az ad sp create-for-rbac --name ServicePrincipalName --role Owner
```

Note: when you are done using the service principal delete it with the command `az ad sp delete --id APPLICATION_ID`

## Target Environments

Choose either environment:

1. [Ubuntu Pipeline](ubuntu)
1. [CentOS Pipeline](centos)
