##########################################################################################################################
# Network Address Translation (NAT) Gateway (https://learn.microsoft.com/azure/virtual-network/nat-gateway/nat-overview) #
##########################################################################################################################

resource "azurerm_nat_gateway" "compute" {
  count               = var.computeNetwork.enableNatGateway ? 1 : 0
  name                = "${local.computeNetworks[0].name}-Gateway"
  resource_group_name = local.computeNetworks[0].resourceGroupName
  location            = local.computeNetworks[0].regionName
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway" "storage" {
  count               = var.storageNetwork.enableNatGateway && local.storageNetwork.enable ? 1 : 0
  name                = "${local.storageNetwork.name}-Gateway"
  resource_group_name = local.storageNetwork.resourceGroupName
  location            = local.storageNetwork.regionName
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "compute" {
  count               = var.computeNetwork.enableNatGateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.compute[0].id
  public_ip_address_id = azurerm_public_ip.nat_gateway_compute[0].id
}

resource "azurerm_nat_gateway_public_ip_association" "storage" {
  count               = var.storageNetwork.enableNatGateway && local.storageNetwork.enable ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.storage[0].id
  public_ip_address_id = azurerm_public_ip.nat_gateway_storage[0].id
}

resource "azurerm_subnet_nat_gateway_association" "compute" {
  for_each = {
    for subnet in local.computeNetworksSubnets : subnet.key => subnet if var.computeNetwork.enableNatGateway
  }
  nat_gateway_id = azurerm_nat_gateway.compute[0].id
  subnet_id      = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
}

resource "azurerm_subnet_nat_gateway_association" "storage" {
  for_each = {
    for subnet in local.storageNetworkSubnets : subnet.key => subnet if var.storageNetwork.enableNatGateway
  }
  nat_gateway_id = azurerm_nat_gateway.storage[0].id
  subnet_id      = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
}
