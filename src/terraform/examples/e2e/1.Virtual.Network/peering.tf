################################################################################################################
# Virtual Network Peering (https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview) #
################################################################################################################

variable "networkPeering" {
  type = object(
    {
      enable                      = bool
      allowRemoteNetworkAccess    = bool
      allowRemoteForwardedTraffic = bool
    }
  )
}

resource "azurerm_virtual_network_peering" "network_peering_up" {
  count                        = var.networkPeering.enable ? length(local.virtualNetworks) - 1 : 0
  name                         = "${local.virtualNetworks[count.index].name}-${local.virtualNetworks[count.index + 1].name}"
  resource_group_name          = azurerm_resource_group.network[0].name
  virtual_network_name         = local.virtualNetworks[count.index].name
  remote_virtual_network_id    = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.virtualNetworks[count.index + 1].name}"
  allow_virtual_network_access = var.networkPeering.allowRemoteNetworkAccess
  allow_forwarded_traffic      = var.networkPeering.allowRemoteForwardedTraffic
  allow_gateway_transit        = contains(local.virtualGatewayNetworkNames, local.virtualNetworks[count.index].name)
  depends_on = [
    azurerm_subnet_network_security_group_association.network
  ]
}

resource "azurerm_virtual_network_peering" "network_peering_down" {
  count                        = var.networkPeering.enable ? length(local.virtualNetworks) - 1 : 0
  name                         = "${local.virtualNetworks[count.index + 1].name}-${local.virtualNetworks[count.index].name}"
  resource_group_name          = azurerm_resource_group.network[0].name
  virtual_network_name         = local.virtualNetworks[count.index + 1].name
  remote_virtual_network_id    = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.virtualNetworks[count.index].name}"
  allow_virtual_network_access = var.networkPeering.allowRemoteNetworkAccess
  allow_forwarded_traffic      = var.networkPeering.allowRemoteForwardedTraffic
  allow_gateway_transit        = contains(local.virtualGatewayNetworkNames, local.virtualNetworks[count.index + 1].name)
  depends_on = [
    azurerm_subnet_network_security_group_association.network
  ]
}
