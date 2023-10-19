##########################################################################################################################
# Network Address Translation (NAT) Gateway (https://learn.microsoft.com/azure/virtual-network/nat-gateway/nat-overview) #
##########################################################################################################################

variable "natGateway" {
  type = object({
    enable = bool
  })
}

resource "azurerm_nat_gateway" "studio" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if var.natGateway.enable && !var.existingNetwork.enable
  }
  name                = "Gateway"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  sku_name            = "Standard"
  depends_on = [
    azurerm_resource_group.network_regions
  ]
}

# resource "azurerm_nat_gateway_public_ip_prefix_association" "studio" {
#   for_each = {
#     for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if var.natGateway.enable && !var.existingNetwork.enable
#   }
#   nat_gateway_id      = azurerm_nat_gateway.studio[each.value.name].id
#   public_ip_prefix_id = azurerm_public_ip_prefix.nat_gateway[each.value.name].id
# }

resource "azurerm_nat_gateway_public_ip_association" "studio" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if var.natGateway.enable && !var.existingNetwork.enable
  }
  nat_gateway_id       = azurerm_nat_gateway.studio[each.value.name].id
  public_ip_address_id = azurerm_public_ip.nat_gateway[each.value.name].id
}

resource "azurerm_subnet_nat_gateway_association" "studio" {
  for_each = {
    for subnet in local.virtualNetworksSubnets : "${subnet.virtualNetworkName}-${subnet.name}" => subnet if var.natGateway.enable && subnet.name != "GatewaySubnet" && !var.existingNetwork.enable
  }
  nat_gateway_id = azurerm_nat_gateway.studio[each.value.virtualNetworkName].id
  subnet_id      = "${each.value.virtualNetworkId}/subnets/${each.value.name}"
  depends_on = [
    azurerm_subnet.studio
  ]
}
