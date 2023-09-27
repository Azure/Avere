###########################################################################
# Open AI (https://learn.microsoft.com/azure/ai-services/openai/overview) #
###########################################################################

variable "openAI" {
  type = object(
    {
      enable      = bool
      regionName  = string
      accountName = string
      domainName  = string
      serviceTier = string
      modelDeployments = list(object(
        {
          enable  = bool
          name    = string
          format  = string
          version = string
          scale   = string
        }
      ))
      storage = object(
        {
          enable = bool
        }
      )
    }
  )
}

resource "azurerm_cognitive_account" "open_ai" {
  count                 = var.openAI.enable ? 1 : 0
  name                  = var.openAI.accountName
  resource_group_name   = azurerm_resource_group.farm.name
  location              = var.openAI.regionName
  custom_subdomain_name = var.openAI.domainName != "" ? var.openAI.domainName : null
  sku_name              = var.openAI.serviceTier
  kind                  = "OpenAI"
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  dynamic storage {
    for_each = var.openAI.storage.enable ? [1] : []
    content {
      storage_account_id = data.azurerm_storage_account.studio.id
    }
  }
}

resource "azurerm_cognitive_deployment" "open_ai" {
  for_each = {
    for modelDeployment in var.openAI.modelDeployments : modelDeployment.name => modelDeployment if var.openAI.enable && modelDeployment.enable
  }
  name                   = each.value.name
  cognitive_account_id   = azurerm_cognitive_account.open_ai[0].id
  # version_upgrade_option = "OnceCurrentVersionExpired"
  model {
    name    = each.value.name
    format  = each.value.format
    version = each.value.version
  }
  scale {
    type = each.value.scale
  }
}

output "openAI" {
  value = var.openAI.enable ? azurerm_cognitive_account.open_ai[0].endpoint : ""
}
