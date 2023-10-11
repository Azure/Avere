################################################################################
# Azure OpenAI (https://learn.microsoft.com/azure/ai-services/openai/overview) #
################################################################################

variable "azureOpenAI" {
  type = object({
    enable      = bool
    regionName  = string
    accountName = string
    domainName  = string
    serviceTier = string
    chatDeployment = object({
      model = object({
        name    = string
        format  = string
        version = string
        scale   = string
      })
      session = object({
        context = string
        request = string
      })
    })
    imageGeneration = object({
      description = string
      height      = number
      width       = number
    })
    storage = object({
      enable = bool
    })
  })
}

resource "azurerm_cognitive_account" "open_ai" {
  count                 = var.azureOpenAI.enable ? 1 : 0
  name                  = var.azureOpenAI.accountName
  resource_group_name   = azurerm_resource_group.farm.name
  location              = var.azureOpenAI.regionName
  custom_subdomain_name = var.azureOpenAI.domainName != "" ? var.azureOpenAI.domainName : null
  sku_name              = var.azureOpenAI.serviceTier
  kind                  = "OpenAI"
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  dynamic storage {
    for_each = var.azureOpenAI.storage.enable ? [1] : []
    content {
      storage_account_id = data.azurerm_storage_account.studio.id
    }
  }
}

resource "azurerm_cognitive_deployment" "open_ai_chat" {
  count                = var.azureOpenAI.enable ? 1 : 0
  name                 = var.azureOpenAI.chatDeployment.model.name
  cognitive_account_id = azurerm_cognitive_account.open_ai[0].id
  model {
    name    = var.azureOpenAI.chatDeployment.model.name
    format  = var.azureOpenAI.chatDeployment.model.format
    version = var.azureOpenAI.chatDeployment.model.version
  }
  scale {
    type = var.azureOpenAI.chatDeployment.model.scale
  }
}

output "azureOpenAI" {
  value = {
    enable   = var.azureOpenAI.enable
    endpoint = var.azureOpenAI.enable ? azurerm_cognitive_account.open_ai[0].endpoint : ""
  }
}
