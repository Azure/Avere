######################################################################
# Monitor (https://learn.microsoft.com/azure/azure-monitor/overview) #
######################################################################

variable "monitor" {
  type = object({
    workspace = object({
      sku = string
    })
    insight = object({
      type = string
    })
    retentionDays = number
  })
}

resource "azurerm_log_analytics_workspace" "monitor" {
  count                      = module.global.monitor.enable ? 1 : 0
  name                       = module.global.monitor.name
  resource_group_name        = azurerm_resource_group.studio.name
  location                   = azurerm_resource_group.studio.location
  sku                        = var.monitor.workspace.sku
  retention_in_days          = var.monitor.retentionDays
  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

resource "azurerm_application_insights" "monitor" {
  count                      = module.global.monitor.enable ? 1 : 0
  name                       = module.global.monitor.name
  resource_group_name        = azurerm_resource_group.studio.name
  location                   = azurerm_resource_group.studio.location
  workspace_id               = azurerm_log_analytics_workspace.monitor[0].id
  application_type           = var.monitor.insight.type
  retention_in_days          = var.monitor.retentionDays
  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

output "monitor" {
  value = {
    enable = module.global.monitor.enable
    workspace = {
      name = module.global.monitor.name
      id   = module.global.monitor.enable ? azurerm_log_analytics_workspace.monitor[0].workspace_id : ""
    }
    insight = {
      name = module.global.monitor.name
      id   = module.global.monitor.enable ? azurerm_application_insights.monitor[0].app_id : ""
    }
  }
}
