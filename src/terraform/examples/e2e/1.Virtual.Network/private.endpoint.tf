###############################################################################################
# Private Endpoint (https://learn.microsoft.com/azure/private-link/private-endpoint-overview) #
###############################################################################################

resource "azurerm_private_dns_zone" "key_vault" {
  count               = module.global.keyVault.enable && var.virtualNetwork.name == "" ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone" "storage_blob" {
  count               = var.virtualNetwork.name == "" ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone" "storage_file" {
  count               = var.virtualNetwork.name == "" ? 1 : 0
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  count                 = module.global.keyVault.enable && var.virtualNetwork.name == "" ? 1 : 0
  name                  = "${local.computeNetworks[0].name}-vault"
  resource_group_name   = azurerm_resource_group.network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetworks[0].name}"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  count                 = var.virtualNetwork.name == "" ? 1 : 0
  name                  = "${local.computeNetworks[0].name}-blob"
  resource_group_name   = azurerm_resource_group.network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob[0].name
  virtual_network_id    = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetworks[0].name}"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_file" {
  count                 = var.virtualNetwork.name == "" ? 1 : 0
  name                  = "${local.computeNetworks[0].name}-file"
  resource_group_name   = azurerm_resource_group.network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.storage_file[0].name
  virtual_network_id    = "${azurerm_resource_group.network[0].id}/providers/Microsoft.Network/virtualNetworks/${local.computeNetworks[0].name}"
  depends_on = [
    azurerm_virtual_network.network
  ]
}

resource "azurerm_private_endpoint" "key_vault" {
  count               = module.global.keyVault.enable && var.virtualNetwork.name == "" ? 1 : 0
  name                = "${data.azurerm_key_vault.studio[0].name}-vault"
  resource_group_name = azurerm_resource_group.network[0].name
  location            = azurerm_resource_group.network[0].location
  subnet_id           = "${azurerm_private_dns_zone_virtual_network_link.key_vault[0].virtual_network_id}/subnets/${local.computeNetworks[0].subnets[local.computeNetworks[0].subnetIndex.storage].name}"
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
    azurerm_subnet.network,
    azurerm_private_dns_zone_virtual_network_link.key_vault
  ]
}

resource "azurerm_private_endpoint" "key_vault_batch" {
  count               = module.global.keyVault.enable && var.virtualNetwork.name == "" ? 1 : 0
  name                = "${data.azurerm_key_vault.studio[0].name}-vault-batch"
  resource_group_name = azurerm_resource_group.network[0].name
  location            = azurerm_resource_group.network[0].location
  subnet_id           = "${azurerm_private_dns_zone_virtual_network_link.key_vault[0].virtual_network_id}/subnets/${local.computeNetworks[0].subnets[local.computeNetworks[0].subnetIndex.storage].name}"
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
    azurerm_subnet.network,
    azurerm_private_dns_zone_virtual_network_link.key_vault
  ]
}

resource "azurerm_private_endpoint" "storage_blob" {
  for_each = {
    for subnet in local.storageSubnets : subnet.key => subnet if var.virtualNetwork.name == ""
  }
  name                = "${data.azurerm_storage_account.studio.name}-blob"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  subnet_id           = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
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
    azurerm_private_endpoint.key_vault,
    azurerm_private_dns_zone_virtual_network_link.storage_blob
  ]
}

resource "azurerm_private_endpoint" "storage_file" {
  for_each = {
    for subnet in local.storageSubnets : subnet.key => subnet if var.virtualNetwork.name == ""
  }
  name                = "${data.azurerm_storage_account.studio.name}-file"
  resource_group_name = each.value.resourceGroupName
  location            = each.value.regionName
  subnet_id           = "${each.value.resourceGroupId}/providers/Microsoft.Network/virtualNetworks/${each.value.virtualNetworkName}/subnets/${each.value.name}"
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
    azurerm_private_endpoint.storage_blob,
    azurerm_private_dns_zone_virtual_network_link.storage_file
  ]
}
