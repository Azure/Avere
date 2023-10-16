resource "azurerm_servicebus_namespace" "studio" {
  count               = var.functionApp.enable ? 1 : 0
  name                = var.functionApp.name
  resource_group_name = azurerm_resource_group.farm.name
  location            = azurerm_resource_group.farm.location
  sku                 = "Standard"
}
