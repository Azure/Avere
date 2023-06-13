#############################
# Public IP Addresses (VPN) #
#############################

resource "azurerm_public_ip" "vpn_gateway_address1" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if var.networkGateway.type == "Vpn"
  }
  name                = local.virtualGatewayActiveActive ? "${each.value.name}1" : "${each.value.name}"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_public_ip" "vpn_gateway_address2" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if local.virtualGatewayActiveActive
  }
  name                = "${each.value.name}2"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_public_ip" "vpn_gateway_address3" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if local.virtualGatewayActiveActive && length(var.vpnGateway.pointToSiteClient.addressSpace) > 0
  }
  name                = "${each.value.name}3"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  sku                 = "Standard"
  allocation_method   = "Static"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

#################################
# Virtual Network Gateway (VPN) #
#################################

resource "azurerm_virtual_network_gateway" "vpn" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if var.networkGateway.type == "Vpn"
  }
  name                = each.value.name
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  type                = var.networkGateway.type
  sku                 = var.vpnGateway.sku
  vpn_type            = var.vpnGateway.type
  generation          = var.vpnGateway.generation
  enable_bgp          = var.vpnGateway.enableBgp
  active_active       = local.virtualGatewayActiveActive
  ip_configuration {
    name                 = "ipConfig1"
    public_ip_address_id = "${each.value.resourceGroupId}/providers/Microsoft.Network/publicIPAddresses/${each.value.name}${local.virtualGatewayActiveActive ? "1" : ""}"
    subnet_id            = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
  }
  dynamic ip_configuration {
    for_each = local.virtualGatewayActiveActive ? [1] : []
    content {
      name                 = "ipConfig2"
      public_ip_address_id = "${each.value.resourceGroupId}/providers/Microsoft.Network/publicIPAddresses/${each.value.name}2"
      subnet_id            = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
    }
  }
  dynamic ip_configuration {
    for_each = local.virtualGatewayActiveActive && length(var.vpnGateway.pointToSiteClient.addressSpace) > 0 ? [1] : []
    content {
      name                 = "ipConfig3"
      public_ip_address_id = "${each.value.resourceGroupId}/providers/Microsoft.Network/publicIPAddresses/${each.value.name}3"
      subnet_id            = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
    }
  }
  dynamic vpn_client_configuration {
    for_each = length(var.vpnGateway.pointToSiteClient.addressSpace) > 0 ? [1] : []
    content {
      address_space = var.vpnGateway.pointToSiteClient.addressSpace
      root_certificate {
        name             = var.vpnGateway.pointToSiteClient.certificateName
        public_cert_data = var.vpnGateway.pointToSiteClient.certificateData
      }
    }
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.network,
    azurerm_public_ip.vpn_gateway_address1,
    azurerm_public_ip.vpn_gateway_address2,
    azurerm_public_ip.vpn_gateway_address3
  ]
}

resource "azurerm_virtual_network_gateway_connection" "vnet_to_vnet_up" {
  count                           = var.networkGateway.type == "Vpn" && var.vpnGateway.enableVnet2Vnet && length(local.virtualGatewayNetworks) > 1 ? length(local.virtualGatewayNetworks) - 1 : 0
  name                            = "${local.virtualGatewayNetworks[count.index].name}.${local.virtualGatewayNetworks[count.index + 1].name}"
  resource_group_name             = azurerm_resource_group.network[0].name
  location                        = local.virtualGatewayNetworks[count.index].regionName
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualGatewayNetworks[count.index].name}"
  peer_virtual_network_gateway_id = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualGatewayNetworks[count.index + 1].name}"
  shared_key                      = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.gateway_connection[0].value : var.vpnGateway.sharedKey
  depends_on = [
    azurerm_virtual_network_gateway.vpn
  ]
}

resource "azurerm_virtual_network_gateway_connection" "vnet_to_vnet_down" {
  count                           = var.networkGateway.type == "Vpn" && var.vpnGateway.enableVnet2Vnet && length(local.virtualGatewayNetworks) > 1 ? length(local.virtualGatewayNetworks) - 1 : 0
  name                            = "${local.virtualGatewayNetworks[count.index + 1].name}.${local.virtualGatewayNetworks[count.index].name}"
  resource_group_name             = azurerm_resource_group.network[0].name
  location                        = local.virtualGatewayNetworks[count.index + 1].regionName
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualGatewayNetworks[count.index + 1].name}"
  peer_virtual_network_gateway_id = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworkGateways/${local.virtualGatewayNetworks[count.index].name}"
  shared_key                      = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.gateway_connection[0].value : var.vpnGateway.sharedKey
  depends_on = [
    azurerm_virtual_network_gateway.vpn
  ]
}

##########################################################################################################################
# Local Network Gateway (VPN) (https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#lng) #
##########################################################################################################################

resource "azurerm_local_network_gateway" "vpn" {
  count               = var.networkGateway.type == "Vpn" && var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "" ? 1 : 0
  name                = local.computeNetworks[0].name
  resource_group_name = azurerm_resource_group.network[0].name
  location            = local.computeNetworks[0].regionName
  gateway_fqdn        = var.vpnGatewayLocal.address == "" ? var.vpnGatewayLocal.fqdn : null
  gateway_address     = var.vpnGatewayLocal.fqdn == "" ? var.vpnGatewayLocal.address : null
  address_space       = var.vpnGatewayLocal.addressSpace
  dynamic bgp_settings {
    for_each = var.vpnGatewayLocal.bgp.enable ? [1] : []
    content {
      asn                 = var.vpnGatewayLocal.bgp.asn
      peer_weight         = var.vpnGatewayLocal.bgp.peerWeight
      bgp_peering_address = var.vpnGatewayLocal.bgp.peeringAddress
    }
  }
}

resource "azurerm_virtual_network_gateway_connection" "site_to_site" {
  count                      = var.networkGateway.type == "Vpn" && var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "" ? 1 : 0
  name                       = local.computeNetworks[0].name
  resource_group_name        = azurerm_resource_group.network[0].name
  location                   = local.computeNetworks[0].regionName
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn[count.index].id
  local_network_gateway_id   = azurerm_local_network_gateway.vpn[count.index].id
  shared_key                 = module.global.keyVault.name != "" ? data.azurerm_key_vault_secret.gateway_connection[0].value : var.vpnGateway.sharedKey
  enable_bgp                 = var.vpnGatewayLocal.bgp.enable
}
