variable "functionApp" {
  type = object(
    {
      name = string
      servicePlan = object(
        {
          computeTier = string
          alwaysOn    = bool
        }
      )
    }
  )
}

resource "azurerm_storage_account" "studio" {
  name                     = var.functionApp.name
  resource_group_name      = azurerm_resource_group.ai.name
  location                 = azurerm_resource_group.ai.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_application_insights" "studio" {
  name                = var.functionApp.name
  location            = azurerm_resource_group.ai.location
  resource_group_name = azurerm_resource_group.ai.name
  application_type    = "web"
}

resource "azurerm_service_plan" "studio" {
  name                = var.functionApp.name
  resource_group_name = azurerm_resource_group.ai.name
  location            = azurerm_resource_group.ai.location
  sku_name            = var.functionApp.servicePlan.computeTier
  os_type             = "Windows"
}

resource "azurerm_windows_function_app" "studio" {
  name                          = var.functionApp.name
  resource_group_name           = azurerm_resource_group.ai.name
  location                      = azurerm_resource_group.ai.location
  service_plan_id               = azurerm_service_plan.studio.id
  storage_account_name          = azurerm_storage_account.studio.name
  storage_uses_managed_identity = true
  identity {
    type = "SystemAssigned, UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  site_config {
    application_insights_connection_string = azurerm_application_insights.studio.connection_string
    application_insights_key               = azurerm_application_insights.studio.instrumentation_key
    always_on                              = var.functionApp.servicePlan.alwaysOn
    application_stack {
      dotnet_version = "v7.0"
    }
    cors {
      allowed_origins = [
        "https://portal.azure.com"
      ]
    }
  }
  app_settings = {
    AzureWebJobsStorage     = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.studio.name};AccountKey=${azurerm_storage_account.studio.primary_access_key}"
    AzureOpenAI_ApiEndpoint = azurerm_cognitive_account.open_ai.endpoint
    AzureOpenAI_ApiKey      = azurerm_cognitive_account.open_ai.primary_access_key
  }
}

resource "azurerm_function_app_function" "image_generate" {
  name            = "image-generate"
  language        = "CSharp"
  function_app_id = azurerm_windows_function_app.studio.id
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
    chat = {
      modelName      = "gpt-35-turbo"
      historyContext = "You are the lead singer in a rock band"
      requestMessage = "What do you look like"
    }
    image = {
      description = ""
      height      = 1024
      width       = 1024
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
