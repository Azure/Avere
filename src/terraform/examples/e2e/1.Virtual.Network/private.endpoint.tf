###############################################################################################
# Private Endpoint (https://learn.microsoft.com/azure/private-link/private-endpoint-overview) #
###############################################################################################

resource "azurerm_private_dns_zone" "key_vault" {
  count               = module.global.keyVault.enable && !var.existingNetwork.enable ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone" "storage_blob" {
  count               = !var.existingNetwork.enable ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone" "storage_file" {
  count               = !var.existingNetwork.enable ? 1 : 0
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if module.global.keyVault.enable && !var.existingNetwork.enable
  }
  name                  = "${each.value.name}-vault"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = each.value.id
  depends_on = [
    azurerm_virtual_network.studio
  ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if !var.existingNetwork.enable && !var.existingNetwork.enable
  }
  name                  = "${each.value.name}-blob"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob[0].name
  virtual_network_id    = each.value.id
  depends_on = [
    azurerm_virtual_network.studio
  ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_file" {
  for_each = {
    for virtualNetwork in local.virtualNetworks : virtualNetwork.name => virtualNetwork if !var.existingNetwork.enable && !var.existingNetwork.enable
  }
  name                  = "${each.value.name}-file"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_file[0].name
  virtual_network_id    = each.value.id
  depends_on = [
    azurerm_virtual_network.studio
  ]
}

resource "azurerm_private_endpoint" "key_vault" {
  for_each = {
    for subnet in local.virtualNetworksSubnetStorage : "${subnet.virtualNetworkName}-${subnet.name}" => subnet if !var.existingNetwork.enable
  }
  name                = "${data.azurerm_key_vault.studio[0].name}-vault"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  subnet_id           = "${each.value.virtualNetworkId}/subnets/${each.value.name}"
  private_service_connection {
    name                           = data.azurerm_key_vault.studio[0].name
    private_connection_resource_id = data.azurerm_key_vault.studio[0].id
    is_manual_connection           = false
    subresource_names = [
      "vault"
    ]
  }
  private_dns_zone_group {
    name = data.azurerm_key_vault.studio[0].name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.key_vault[0].id
    ]
  }
  depends_on = [
    azurerm_subnet.studio,
    azurerm_private_dns_zone_virtual_network_link.key_vault
  ]
}

resource "azurerm_private_endpoint" "key_vault_batch" {
  for_each = {
    for subnet in local.virtualNetworksSubnetStorage : "${subnet.virtualNetworkName}-${subnet.name}" => subnet if !var.existingNetwork.enable
  }
  name                = "${data.azurerm_key_vault.batch[0].name}-vault-batch"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  subnet_id           = "${each.value.virtualNetworkId}/subnets/${each.value.name}"
  private_service_connection {
    name                           = data.azurerm_key_vault.batch[0].name
    private_connection_resource_id = data.azurerm_key_vault.batch[0].id
    is_manual_connection           = false
    subresource_names = [
      "vault"
    ]
  }
  private_dns_zone_group {
    name = data.azurerm_key_vault.batch[0].name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.key_vault[0].id
    ]
  }
  depends_on = [
    azurerm_subnet.studio,
    azurerm_private_dns_zone_virtual_network_link.key_vault,
    azurerm_private_endpoint.key_vault
  ]
}

resource "azurerm_private_endpoint" "storage_blob" {
  for_each = {
    for subnet in local.virtualNetworksSubnetStorage : "${subnet.virtualNetworkName}-${subnet.name}" => subnet if !var.existingNetwork.enable
  }
  name                = "${data.azurerm_storage_account.studio.name}-blob"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  subnet_id           = "${each.value.virtualNetworkId}/subnets/${each.value.name}"
  private_service_connection {
    name                           = data.azurerm_storage_account.studio.name
    private_connection_resource_id = data.azurerm_storage_account.studio.id
    is_manual_connection           = false
    subresource_names = [
      "blob"
    ]
  }
  private_dns_zone_group {
    name = data.azurerm_storage_account.studio.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.storage_blob[0].id
    ]
  }
  depends_on = [
    azurerm_subnet.studio,
    azurerm_private_dns_zone_virtual_network_link.storage_blob,
    azurerm_private_endpoint.key_vault_batch
 ]
}

resource "azurerm_private_endpoint" "storage_file" {
  for_each = {
    for subnet in local.virtualNetworksSubnetStorage : "${subnet.virtualNetworkName}-${subnet.name}" => subnet if !var.existingNetwork.enable
  }
  name                = "${data.azurerm_storage_account.studio.name}-file"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  subnet_id           = "${each.value.virtualNetworkId}/subnets/${each.value.name}"
  private_service_connection {
    name                           = data.azurerm_storage_account.studio.name
    private_connection_resource_id = data.azurerm_storage_account.studio.id
    is_manual_connection           = false
    subresource_names = [
      "file"
    ]
  }
  private_dns_zone_group {
    name = data.azurerm_storage_account.studio.name
    private_dns_zone_ids = [
      azurerm_private_dns_zone.storage_file[0].id
    ]
  }
  depends_on = [
    azurerm_subnet.studio,
    azurerm_private_dns_zone_virtual_network_link.storage_file,
    azurerm_private_endpoint.storage_blob
  ]
}
