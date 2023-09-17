###############################################################################################################
# Virtual Network Gateway (VPN) (https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) #
###############################################################################################################

variable "vpnGateway" {
  type = object(
    {
      enable             = bool
      sku                = string
      type               = string
      generation         = string
      sharedKey          = string
      enableBgp          = bool
      enableVnet2Vnet    = bool
      enableActiveActive = bool
      pointToSiteClient = object(
        {
          addressSpace = list(string)
          rootCertificate = object(
            {
              name = string
              data = string
            }
          )
        }
      )
    }
  )
}

variable "vpnGatewayLocal" {
  type = object(
    {
      fqdn         = string
      address      = string
      addressSpace = list(string)
      bgp = object(
        {
          enable         = bool
          asn            = number
          peerWeight     = number
          peeringAddress = string
        }
      )
    }
  )
}

locals {
  virtualGatewayNetworks = var.virtualNetwork.name != "" ? [
    merge(var.virtualNetwork, {
      key             = "${var.virtualNetwork.regionName}.${var.virtualNetwork.name}"
      resourceGroupId = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${var.virtualNetwork.resourceGroupName}"
    })
  ] : [
    for virtualNetwork in var.vpnGateway.enableVnet2Vnet ? local.virtualNetworks : [local.virtualNetworks[0]] : merge({}, {
      key               = "${virtualNetwork.regionName}.${virtualNetwork.name}"
      name              = virtualNetwork.name
      regionName        = virtualNetwork.regionName
      resourceGroupId   = "/subscriptions/${data.azurerm_client_config.studio.subscription_id}/resourceGroups/${virtualNetwork.resourceGroupName}"
      resourceGroupName = virtualNetwork.resourceGroupName
    })
  ]
  virtualGatewayNetworkNames = [
    for virtualGatewayNetwork in local.virtualGatewayNetworks : virtualGatewayNetwork.name
  ]
  virtualGatewayActiveActive = var.vpnGateway.enable && var.vpnGateway.enableActiveActive
}

resource "azurerm_virtual_network_gateway" "vpn" {
  for_each = {
    for virtualNetwork in local.virtualGatewayNetworks : virtualNetwork.key => virtualNetwork if var.vpnGateway.enable
  }
  name                = each.value.name
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  type                = "Vpn"
  sku                 = var.vpnGateway.sku
  vpn_type            = var.vpnGateway.type
  generation          = var.vpnGateway.generation
  enable_bgp          = var.vpnGateway.enableBgp
  active_active       = local.virtualGatewayActiveActive
  ip_configuration {
    name                 = "ipConfig1"
    public_ip_address_id = azurerm_public_ip.vpn_gateway_1[0].id
    subnet_id            = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
  }
  dynamic ip_configuration {
    for_each = local.virtualGatewayActiveActive ? [1] : []
    content {
      name                 = "ipConfig2"
      public_ip_address_id = azurerm_public_ip.vpn_gateway_2[0].id
      subnet_id            = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.name}/subnets/GatewaySubnet"
    }
  }
  dynamic vpn_client_configuration {
    for_each = length(var.vpnGateway.pointToSiteClient.addressSpace) > 0 ? [1] : []
    content {
      address_space = var.vpnGateway.pointToSiteClient.addressSpace
      root_certificate {
        name             = var.vpnGateway.pointToSiteClient.rootCertificate.name
        public_cert_data = var.vpnGateway.pointToSiteClient.rootCertificate.data
      }
    }
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.network,
    azurerm_public_ip.vpn_gateway_1,
    azurerm_public_ip.vpn_gateway_2
  ]
}

resource "azurerm_virtual_network_gateway_connection" "vnet_to_vnet_up" {
  count                           = var.vpnGateway.enable && var.vpnGateway.enableVnet2Vnet && length(local.virtualGatewayNetworks) > 1 ? length(local.virtualGatewayNetworks) - 1 : 0
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
  count                           = var.vpnGateway.enable && var.vpnGateway.enableVnet2Vnet && length(local.virtualGatewayNetworks) > 1 ? length(local.virtualGatewayNetworks) - 1 : 0
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
  count               = var.vpnGateway.enable && var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "" ? 1 : 0
  name                = local.computeNetworks[0].name
  resource_group_name = local.computeNetworks[0].resourceGroupName
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
  depends_on = [
    azurerm_resource_group.network
  ]
}

resource "azurerm_virtual_network_gateway_connection" "site_to_site" {
  count                      = var.vpnGateway.enable && var.vpnGatewayLocal.fqdn != "" || var.vpnGatewayLocal.address != "" ? 1 : 0
  name                       = local.computeNetworks[0].name
  resource_group_name        = azurerm_resource_group.network[0].name
  location                   = local.computeNetworks[0].regionName
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn[local.virtualGatewayNetworks[0].key].id
  local_network_gateway_id   = azurerm_local_network_gateway.vpn[count.index].id
  shared_key                 = var.vpnGateway.sharedKey != "" ? var.vpnGateway.sharedKey : data.azurerm_key_vault_secret.gateway_connection[0].value
  enable_bgp                 = var.vpnGatewayLocal.bgp.enable
}
