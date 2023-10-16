############################################################################
# Private DNS (https://learn.microsoft.com/azure/dns/private-dns-overview) #
############################################################################

variable "privateDns" {
  type = object({
    enable   = bool
    zoneName = string
    autoRegistration = object({
      enable = bool
    })
  })
}

resource "azurerm_private_dns_zone" "studio" {
  count               = var.privateDns.enable && !var.existingNetwork.enable ? 1 : 0
  name                = var.privateDns.zoneName
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "studio" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.key => virtualNetwork if var.privateDns.enable && !var.existingNetwork.enable
  }
  name                  = each.value.key
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.studio[0].name
  virtual_network_id    = each.value.id
  registration_enabled  = var.privateDns.autoRegistration.enable
  depends_on = [
    azurerm_virtual_network.studio
  ]
}

output "privateDns" {
  value = var.existingNetwork.enable ? null : var.privateDns
}
