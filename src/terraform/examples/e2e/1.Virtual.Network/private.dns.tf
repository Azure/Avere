############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

resource "azurerm_private_dns_zone" "studio" {
  count               = var.virtualNetwork.name == "" ? 1 : 0
  name                = var.privateDns.zoneName
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.key => virtualNetwork if var.virtualNetwork.name == ""
  }
  name                  = each.value.key
  resource_group_name   = azurerm_private_dns_zone.studio[0].resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.studio[0].name
  virtual_network_id    = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.name}"
  registration_enabled  = var.privateDns.enableAutoRegistration
  depends_on = [
    azurerm_virtual_network.network
  ]
}
