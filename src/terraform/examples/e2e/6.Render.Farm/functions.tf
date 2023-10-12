#####################################################
# https://learn.microsoft.com/azure/azure-functions #
#####################################################

variable "functionApp" {
  type = object({
    enable = bool
    name   = string
    servicePlan = object({
      computeTier = string
      workerCount = number
    })
    monitor = object({
      workspace = object({
        sku = string
      })
      insight = object({
        type = string
      })
      retentionDays = number
    })
  })
}

# resource "azurerm_private_dns_zone" "function_app" {
#   count               = var.functionApp.enable ? 1 : 0
#   name                = "privatelink.azurewebsites.net"
#   resource_group_name = azurerm_resource_group.farm.name
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "function_app" {
#   count                 = var.functionApp.enable ? 1 : 0
#   name                  = "${var.functionApp.name}-functions"
#   resource_group_name   = azurerm_resource_group.farm.name
#   private_dns_zone_name = azurerm_private_dns_zone.function_app[0].name
#   virtual_network_id    = data.azurerm_virtual_network.compute.id
# }

# resource "azurerm_private_endpoint" "function_app" {
#   count               = var.functionApp.enable ? 1 : 0
#   name                = "${var.functionApp.name}-functions"
#   resource_group_name = azurerm_resource_group.farm.name
#   location            = azurerm_resource_group.farm.location
#   subnet_id           = data.azurerm_subnet.farm.id
#   private_service_connection {
#     name                           = azurerm_windows_function_app.studio[0].name
#     private_connection_resource_id = azurerm_windows_function_app.studio[0].id
#     is_manual_connection           = false
#     subresource_names = [
#       "sites"
#     ]
#   }
#   private_dns_zone_group {
#     name = azurerm_windows_function_app.studio[0].name
#     private_dns_zone_ids = [
#       azurerm_private_dns_zone.function_app[0].id
#     ]
#   }
#   depends_on = [
#     azurerm_private_dns_zone_virtual_network_link.function_app
#   ]
# }

resource "azurerm_log_analytics_workspace" "studio" {
  count                      = var.functionApp.enable ? 1 : 0
  name                       = var.functionApp.name
  resource_group_name        = azurerm_resource_group.farm.name
  location                   = azurerm_resource_group.farm.location
  sku                        = var.functionApp.monitor.workspace.sku
  retention_in_days          = var.functionApp.monitor.retentionDays
  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

resource "azurerm_application_insights" "studio" {
  count                      = var.functionApp.enable ? 1 : 0
  name                       = var.functionApp.name
  resource_group_name        = azurerm_resource_group.farm.name
  location                   = azurerm_resource_group.farm.location
  workspace_id               = azurerm_log_analytics_workspace.studio[0].id
  application_type           = var.functionApp.monitor.insight.type
  retention_in_days          = var.functionApp.monitor.retentionDays
  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

resource "azurerm_service_plan" "studio" {
  count               = var.functionApp.enable ? 1 : 0
  name                = var.functionApp.name
  resource_group_name = azurerm_resource_group.farm.name
  location            = azurerm_resource_group.farm.location
  sku_name            = var.functionApp.servicePlan.computeTier
  worker_count        = var.functionApp.servicePlan.workerCount
  os_type             = "Windows"
}

resource "azurerm_windows_function_app" "studio" {
  count                           = var.functionApp.enable ? 1 : 0
  name                            = var.functionApp.name
  resource_group_name             = azurerm_resource_group.farm.name
  location                        = azurerm_resource_group.farm.location
  service_plan_id                 = azurerm_service_plan.studio[0].id
  key_vault_reference_identity_id = data.azurerm_user_assigned_identity.studio.id
  #virtual_network_subnet_id       = data.azurerm_subnet.farm.id
  storage_account_name            = data.azurerm_storage_account.studio.name
  storage_uses_managed_identity   = true
  #public_network_access_enabled   = false
  builtin_logging_enabled         = true
  https_only                      = true
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  storage_account {
    name         = data.azurerm_storage_account.studio.name
    account_name = data.azurerm_storage_account.studio.name
    access_key   = data.azurerm_storage_account.studio.primary_access_key
    share_name   = data.azurerm_storage_share.studio.name
    type         = "AzureFiles"
  }
  site_config {
    application_insights_connection_string = azurerm_application_insights.studio[0].connection_string
    application_insights_key               = azurerm_application_insights.studio[0].instrumentation_key
    health_check_path                      = "/"
    cors {
      allowed_origins = [
        "https://portal.azure.com"
      ]
    }
  }
  app_settings = {
    AzureWebJobsStorage     = "DefaultEndpointsProtocol=https;AccountName=${data.azurerm_storage_account.studio.name};AccountKey=${data.azurerm_storage_account.studio.primary_access_key}"
    AzureOpenAI_ApiEndpoint = azurerm_cognitive_account.open_ai[0].endpoint
    AzureOpenAI_ApiKey      = azurerm_cognitive_account.open_ai[0].primary_access_key
  }
}

resource "azurerm_function_app_function" "image_generate" {
  count           = var.functionApp.enable ? 1 : 0
  name            = "image-generate"
  language        = "CSharp"
  function_app_id = azurerm_windows_function_app.studio[0].id
  config_json = jsonencode({
    bindings = [
      {
        name      = "request"
        type      = "httpTrigger"
        direction = "in"
        authLevel = "function"
        methods = [
          "post"
        ]
      },
      {
        name      = "$return"
        type      = "http"
        direction = "out"
      }
    ]
  })
  test_data = jsonencode({
    chatDeployment = {
      modelName      = var.azureOpenAI.chatDeployment.model.name
      historyContext = var.azureOpenAI.chatDeployment.session.context
      requestMessage = var.azureOpenAI.chatDeployment.session.request
    }
    imageGeneration = {
      description = var.azureOpenAI.imageGeneration.description
      height      = var.azureOpenAI.imageGeneration.height
      width       = var.azureOpenAI.imageGeneration.width
    }
  })
  file {
    name    = "function.proj"
    content = file("image.generate/function.proj")
  }
  file {
    name    = "run.csx"
    content = file("image.generate/run.csx")
  }
}

output "functionApp" {
  value = {
    enable   = var.functionApp.enable
    endpoint = var.functionApp.enable ? azurerm_windows_function_app.studio[0].default_hostname : ""
  }
}
