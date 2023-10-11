############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

variable "privateDns" {
  type = object({
    zoneName = string
    autoRegistration = object({
      enable = bool
    })
  })
}

resource "azurerm_private_dns_zone" "studio" {
  count               = var.privateDns.zoneName != "" ? 1 : 0
  name                = var.privateDns.zoneName
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.key => virtualNetwork if var.virtualNetwork.name == "" && var.privateDns.zoneName != ""
  }
  name                  = each.value.key
  resource_group_name   = azurerm_private_dns_zone.studio[0].resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.studio[0].name
  virtual_network_id    = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.name}"
  registration_enabled  = var.privateDns.autoRegistration.enable
  depends_on = [
    azurerm_virtual_network.studio
  ]
}

output "privateDns" {
  value = var.virtualNetwork.enable ? null : var.privateDns
}
