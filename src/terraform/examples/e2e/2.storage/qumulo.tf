####################################################################################################
# Qumulo (https://azuremarketplace.microsoft.com/marketplace/apps/qumulo1584033880660.qumulo-saas) #
####################################################################################################

variable "qumulo" {
  type = object(
    {
      name      = string
      planId    = string
      offerId   = string
      termId    = string
      autoRenew = bool
    }
  )
}

resource "azurerm_resource_group" "qumulo" {
  count    = var.qumulo.name != "" ? 1 : 0
  name     = "${var.resourceGroupName}.Qumulo"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_resource_group_template_deployment" "qumulo" {
  count               = var.qumulo.name != "" ? 1 : 0
  name                = var.qumulo.name
  resource_group_name = azurerm_resource_group.qumulo[0].name
  deployment_mode     = "Incremental"
  parameters_content  = jsonencode({
    "name" = {
      value = var.qumulo.name
    },
    "planId" = {
      value = var.qumulo.planId
    },
    "offerId" = {
      value = var.qumulo.offerId
    },
    "termId" = {
      value = var.qumulo.termId
    },
    "autoRenew" = {
      value = var.qumulo.autoRenew
    }
  })
  template_content = <<TEMPLATE
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "name": {
          "type": "string"
        },
        "planId": {
          "type": "string"
        },
        "offerId": {
          "type": "string"
        },
        "termId": {
          "type": "string"
        },
        "autoRenew": {
          "type": "bool"
        }
      },
      "variables": {
      },
      "functions": [
      ],
      "resources": [
        {
          "type": "Microsoft.SaaS/resources",
          "name": "[parameters('name')]",
          "apiVersion": "2018-03-01-beta",
          "location": "global",
          "properties": {
            "publisherId": "qumulo1584033880660",
            "skuId": "[parameters('planId')]",
            "offerId": "[parameters('offerId')]",
            "termId": "[if(equals(parameters('termId'), 'Monthly'), 'gmz7xq9ge3py', 'o73usof6rkyy')]",
            "autoRenew": "[parameters('autoRenew')]",
            "paymentChannelType": "SubscriptionDelegated",
            "paymentChannelMetadata": {
              "AzureSubscriptionId": "[subscription().subscriptionId]"
            }
          }
        }
      ],
      "outputs": {
      }
    }
  TEMPLATE
}
