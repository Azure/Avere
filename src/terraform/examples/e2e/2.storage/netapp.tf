#######################################################################################################
# NetApp Files (https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) #
#######################################################################################################

variable "netAppAccount" {
  type = object(
    {
      name = string
      capacityPools = list(object(
        {
          name         = string
          sizeTiB      = number
          serviceLevel = string
          volumes = list(object(
            {
              name         = string
              sizeGiB      = number
              serviceLevel = string
              mountPath    = string
              protocols    = list(string)
              exportPolicies = list(object(
                {
                  ruleIndex      = number
                  readOnly       = bool
                  readWrite      = bool
                  rootAccess     = bool
                  protocols      = list(string)
                  allowedClients = list(string)
                }
              ))
            }
          ))
        }
      ))
    }
  )
}

data "azurerm_subnet" "storage_netapp" {
  count                = (!local.stateExistsNetwork && var.storageNetwork.name != "") || (local.stateExistsNetwork && data.terraform_remote_state.network.outputs.storageNetwork.name != "") ? 1 : 0
  name                 = !local.stateExistsNetwork ? var.storageNetwork.subnetNamePrimary : data.terraform_remote_state.network.outputs.storageNetwork.subnets[data.terraform_remote_state.network.outputs.storageNetwork.subnetIndex.netAppFiles].name
  resource_group_name  = data.azurerm_virtual_network.storage[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.storage[0].name
}

locals {
  netAppVolumes = flatten([
    for capacityPool in var.netAppAccount.capacityPools : [
      for volume in capacityPool.volumes : merge(volume,
        {capacityPoolName = capacityPool.name}
      ) if volume.name != ""
    ] if capacityPool.name != "" && var.netAppAccount.name != ""
  ])
}

resource "azurerm_resource_group" "netapp_files" {
  count    = var.netAppAccount.name != "" ? 1 : 0
  name     = "${var.resourceGroupName}.NetAppFiles"
  location = azurerm_resource_group.storage.location
}

resource "azurerm_netapp_account" "storage" {
  count               = var.netAppAccount.name != "" ? 1 : 0
  name                = var.netAppAccount.name
  resource_group_name = azurerm_resource_group.netapp_files[0].name
  location            = azurerm_resource_group.netapp_files[0].location
}

resource "azurerm_netapp_pool" "storage" {
  for_each = {
    for capacityPool in var.netAppAccount.capacityPools : capacityPool.name => capacityPool if var.netAppAccount.name != ""
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.netapp_files[0].name
  location            = azurerm_resource_group.netapp_files[0].location
  size_in_tb          = each.value.sizeTiB
  service_level       = each.value.serviceLevel
  account_name        = var.netAppAccount.name
  depends_on = [
    azurerm_netapp_account.storage
  ]
}

resource "azurerm_netapp_volume" "storage" {
  for_each = {
    for volume in local.netAppVolumes : "${volume.capacityPoolName}.${volume.name}" => volume
  }
  name                = each.value.name
  resource_group_name = azurerm_resource_group.netapp_files[0].name
  location            = azurerm_resource_group.netapp_files[0].location
  storage_quota_in_gb = each.value.sizeGiB
  service_level       = each.value.serviceLevel
  volume_path         = each.value.mountPath
  protocols           = each.value.protocols
  pool_name           = each.value.capacityPoolName
  account_name        = var.netAppAccount.name
  subnet_id           = data.azurerm_subnet.storage_netapp[0].id
  dynamic export_policy_rule {
    for_each = each.value.exportPolicies
    content {
      rule_index          = export_policy_rule.value["ruleIndex"]
      unix_read_only      = export_policy_rule.value["readOnly"]
      unix_read_write     = export_policy_rule.value["readWrite"]
      root_access_enabled = export_policy_rule.value["rootAccess"]
      protocols_enabled   = export_policy_rule.value["protocols"]
      allowed_clients     = export_policy_rule.value["allowedClients"]
    }
  }
  depends_on = [
    azurerm_netapp_pool.storage
  ]
}
