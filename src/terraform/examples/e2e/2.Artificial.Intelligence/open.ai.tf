variable "openAI" {
  type = object(
    {
      regionName    = string
      accountName   = string
      domainName    = string
      serviceTier   = string
      enableStorage = bool
      networkAccess = object(
        {
          enablePublic     = bool
          restrictOutbound = bool
        }
      )
      modelDeployments = list(object(
        {
          name    = string
          format  = string
          version = string
          scale   = string
        }
      ))
    }
  )
}

resource "azurerm_private_dns_zone" "cognitive_services" {
  count               = var.openAI.networkAccess.enablePublic ? 0 : 1
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = azurerm_resource_group.ai.name
}

resource "azurerm_private_dns_zone" "open_ai" {
  count               = var.openAI.networkAccess.enablePublic ? 0 : 1
  name                = "privatelink.openai.azure.com"
  resource_group_name = azurerm_resource_group.ai.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "cognitive_services" {
  count                 = var.openAI.networkAccess.enablePublic ? 0 : 1
  name                  = "${data.azurerm_virtual_network.compute.name}.cognitive-services"
  resource_group_name   = azurerm_resource_group.ai.name
  private_dns_zone_name = azurerm_private_dns_zone.cognitive_services[0].name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "open_ai" {
  count                 = var.openAI.networkAccess.enablePublic ? 0 : 1
  name                  = "${data.azurerm_virtual_network.compute.name}.open-ai"
  resource_group_name   = azurerm_resource_group.ai.name
  private_dns_zone_name = azurerm_private_dns_zone.open_ai[0].name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
}

# resource "azurerm_private_endpoint" "cognitive_services" {
#   count               = var.openAI.networkAccess.enablePublic ? 0 : 1
#   name                = "${data.azurerm_virtual_network.compute.name}.cognitive-services"
#   resource_group_name = azurerm_resource_group.ai.name
#   location            = azurerm_resource_group.ai.location
#   subnet_id           = data.azurerm_subnet.farm.id
#   private_service_connection {
#     name                           = azurerm_cognitive_account.open_ai.name
#     private_connection_resource_id = azurerm_cognitive_account.open_ai.id
#     is_manual_connection           = false
#     subresource_names = [
#       "account"
#     ]
#   }
#   private_dns_zone_group {
#     name = azurerm_cognitive_account.open_ai.name
#     private_dns_zone_ids = [
#       azurerm_private_dns_zone.cognitive_services.id
#     ]
#   }
# }

# resource "azurerm_private_endpoint" "open_ai" {
#   name                = "${data.azurerm_virtual_network.compute.name}.open-ai"
#   resource_group_name = azurerm_resource_group.ai.name
#   location            = azurerm_resource_group.ai.location
#   subnet_id           = data.azurerm_subnet.farm.id
#   private_service_connection {
#     name                           = azurerm_cognitive_account.open_ai.name
#     private_connection_resource_id = azurerm_cognitive_account.open_ai.id
#     is_manual_connection           = false
#     subresource_names = [
#       "account"
#     ]
#   }
#   private_dns_zone_group {
#     name = azurerm_cognitive_account.open_ai.name
#     private_dns_zone_ids = [
#       azurerm_private_dns_zone.open_ai.id
#     ]
#   }
# }

resource "azurerm_cognitive_account" "open_ai" {
  name                               = var.openAI.accountName
  resource_group_name                = azurerm_resource_group.ai.name
  location                           = azurerm_resource_group.ai.location
  public_network_access_enabled      = var.openAI.networkAccess.enablePublic
  outbound_network_access_restricted = var.openAI.networkAccess.restrictOutbound
  custom_subdomain_name              = var.openAI.domainName != "" ? var.openAI.domainName : null
  sku_name                           = var.openAI.serviceTier
  kind                               = "OpenAI"
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  dynamic network_acls {
    for_each = var.openAI.networkAccess.enablePublic ? [] : [1]
    content {
      default_action = "Deny"
      virtual_network_rules {
        subnet_id = data.azurerm_subnet.farm.id
      }
    }
  }
  dynamic storage {
    for_each = var.openAI.enableStorage ? [1] : []
    content {
      storage_account_id = data.azurerm_storage_account.studio.id
    }
  }
}

resource "azurerm_cognitive_deployment" "open_ai" {
  for_each = {
    for modelDeployment in var.openAI.modelDeployments : modelDeployment.name => modelDeployment if modelDeployment.name != ""
  }
  name                   = each.value.name
  cognitive_account_id   = azurerm_cognitive_account.open_ai.id
  # version_upgrade_option = "OnceCurrentVersionExpired"
  model {
    name    = each.value.name
    format  = each.value.format
    version = each.value.version
  }
  scale {
    type = each.value.scale
  }
}

output "openAI" {
  value = azurerm_cognitive_account.open_ai.endpoint
}
