data "azurerm_log_analytics_workspace" "studio" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = module.global.monitor.name
  resource_group_name = module.global.resourceGroupName
}

data "azurerm_application_insights" "studio" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = module.global.monitor.name
  resource_group_name = module.global.resourceGroupName
}

######################################################################
# Monitor (https://learn.microsoft.com/azure/azure-monitor/overview) #
######################################################################

resource "azurerm_private_dns_zone" "monitor" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = "privatelink.monitor.azure.com"
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone" "monitor_opinsights_oms" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = "privatelink.oms.opinsights.azure.com"
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone" "monitor_opinsights_ods" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = "privatelink.ods.opinsights.azure.com"
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone" "monitor_automation" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = "privatelink.agentsvc.azure-automation.net"
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor" {
  count                 = module.global.monitor.name != "" ? 1 : 0
  name                  = "${local.computeNetworks[0].name}.monitor"
  resource_group_name   = azurerm_resource_group.network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.monitor[0].name
  virtual_network_id    = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetworks[0].name}"
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor_opinsights_oms" {
  count                 = module.global.monitor.name != "" ? 1 : 0
  name                  = "${local.computeNetworks[0].name}.monitor.opinsights.oms"
  resource_group_name   = azurerm_resource_group.network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.monitor_opinsights_oms[0].name
  virtual_network_id    = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetworks[0].name}"
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor_opinsights_ods" {
  count                 = module.global.monitor.name != "" ? 1 : 0
  name                  = "${local.computeNetworks[0].name}.monitor.opinsights.ods"
  resource_group_name   = azurerm_resource_group.network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.monitor_opinsights_ods[0].name
  virtual_network_id    = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetworks[0].name}"
}

resource "azurerm_private_dns_zone_virtual_network_link" "monitor_automation" {
  count                 = module.global.monitor.name != "" ? 1 : 0
  name                  = "${local.computeNetworks[0].name}.monitor.automation"
  resource_group_name   = azurerm_resource_group.network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.monitor_automation[0].name
  virtual_network_id    = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetworks[0].name}"
}

resource "azurerm_private_endpoint" "monitor" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = "${azurerm_monitor_private_link_scope.monitor[0].name}.monitor"
  resource_group_name = azurerm_resource_group.network[0].name
  location            = azurerm_resource_group.network[0].location
  subnet_id           = "${azurerm_private_dns_zone_virtual_network_link.monitor[0].virtual_network_id}/subnets/${local.computeNetworks[0].subnets[local.computeNetworks[0].subnetIndex.storage].name}"
  private_service_connection {
    name                           = azurerm_monitor_private_link_scope.monitor[0].name
    private_connection_resource_id = azurerm_monitor_private_link_scope.monitor[0].id
    is_manual_connection           = false
    subresource_names = [
      "azuremonitor"
    ]
  }
  private_dns_zone_group {
    name = azurerm_monitor_private_link_scope.monitor[0].name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.monitor[0].id,
      azurerm_private_dns_zone.monitor_opinsights_oms[0].id,
      azurerm_private_dns_zone.monitor_opinsights_ods[0].id,
      azurerm_private_dns_zone.monitor_automation[0].id,
      azurerm_private_dns_zone.storage_blob[0].id
    ]
  }
  depends_on = [
    azurerm_private_endpoint.storage_file
  ]
}

resource "azurerm_monitor_private_link_scope" "monitor" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = module.global.monitor.name
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_monitor_private_link_scoped_service" "monitor_workspace" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = "${module.global.monitor.name}.workspace"
  resource_group_name = azurerm_resource_group.network[0].name
  linked_resource_id  = data.azurerm_log_analytics_workspace.studio[0].id
  scope_name          = azurerm_monitor_private_link_scope.monitor[0].name
}

resource "azurerm_monitor_private_link_scoped_service" "monitor_insight" {
  count               = module.global.monitor.name != "" ? 1 : 0
  name                = "${module.global.monitor.name}.insight"
  resource_group_name = azurerm_resource_group.network[0].name
  linked_resource_id  = data.azurerm_application_insights.studio[0].id
  scope_name          = azurerm_monitor_private_link_scope.monitor[0].name
}
