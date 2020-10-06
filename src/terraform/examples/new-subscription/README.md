# Best Practices for a New Subscription

It may be useful for a studio to create a subscription for each office, or each new show to separate out billing.

If you have created a new subscription, you will need to perform the following steps one time only for the new subscription as "Owner" role:

1. login to https://portal.azure.com with an "Owner" role.

1. browse to https://shell.azure.com

1. execute the following substiting in your subscription id `az account set --subscription <SUBSCRIPTION_ID>`

1. cause Terraform to pre-register to all providers.  This is done by creating / destroying a dummy resource group.
    1. execute `mkdir ~/registerrpfirsttimesub && cd ~/registerrpfirsttimesub`
    1. edit `main.tf` and add the following content
    ```bash
    provider "azurerm" {
        version = "~>2.12.0"
        features {}
    }
    
    resource "azurerm_resource_group" "registerrg" {
      name     = "registerrg"
      location = "westus"
    }
    ```
    1. `terraform init`
    1. `terraform apply -auto-approve`
    1. `terraform destroy -auto-approve`
    1. `cd && rm -rf ~/registerrpfirsttimesub`

1. If you are deploying the Avere vFXT, register the controller `az vm image accept-terms --urn microsoft-avere:vfxt:avere-vfxt-controller:latest`

1. If you are deploying the Avere vFXT, and using a user assigned managed identity, as "Owner" follow the process to create the [managed identity](../vfxt/user-assigned-managed-identity#create-the-resource-groups-service-principal-and-managed-identities)

