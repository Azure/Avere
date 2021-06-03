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
    terraform {
      required_version = ">= 0.14.0,< 0.16.0"
      required_providers {
        azurerm = {
          source  = "hashicorp/azurerm"
          version = "~>2.56.0"
        }
      }
    }

    provider "azurerm" {
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

1. If you are deploying the Avere vFXT, register the controller `az vm image terms accept --urn microsoft-avere:vfxt:avere-vfxt-controller:latest`

1. If you are deploying the Avere vFXT, and using a user assigned managed identity, as "Owner" follow the process to create the [managed identity](../vfxt/user-assigned-managed-identity#create-the-resource-groups-service-principal-and-managed-identities)

1. You can confirm quota on your subscription in the [Azure Portal](https://portal.azure.com) or via the [Azure Quota REST API](https://docs.microsoft.com/en-gb/rest/api/reserved-vm-instances/quotaapi). You will need to ensure you have the required quota for compute render nodes, and compute for vFXT (not required if you are using HPC Cache). Example quota check in West Europe for vFXT:
    ```
    # Register the Microsoft Capacity resource provider on your subscription. This step only has to be completed once per subscription.
    az provider register --namespace Microsoft.Capacity
    az provider show -n Microsoft.Capacity -o table
    # Use 'az rest' to call the Azure Quota API
    az rest -u https://management.azure.com/subscriptions/{YOUR SUBSCRIPTION ID>/providers/Microsoft.Capacity/resourceProviders/Microsoft.Compute/locations/westeurope/serviceLimits/standardESv3Family?api-version=2020-10-25 --query "[name, properties.currentValue, properties.limit]" -o table
    ```
    
    1. To get resource names:
    `az vm list-skus -l westeurope -r virtualMachines --query "[].[name, family]" -o table`

    1. To get locations:
    `az account list-locations --query "[?metadata.regionType == 'Physical'].[name, metadata.latitude, metadata.longitude]" -o table`
    
    Example quota check in westeurope region for Spot cores:
    
    ```
    az rest -u https://management.azure.com/subscriptions/{YOUR SUBSCRIPTION ID>/providers/Microsoft.Capacity/resourceProviders/Microsoft.Compute/locations/westeurope/serviceLimits/lowPriorityCores?api-version=2020-10-25 --query "[name, properties.currentValue, properties.limit]" -o table
    ```

1. If you have quota, and are able to deploy as standard, but are unable to deploy SPOT, and you are on a CSP subscription, ask your CSP to confirm that you have a type "Modern" on your Azure account.