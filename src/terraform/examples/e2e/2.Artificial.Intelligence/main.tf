terraform {
  required_version = ">= 1.4.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.59.0"
    }
  }
  backend "azurerm" {
    key = "2.Artificial.Intelligence"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
}

module "global" {
  source = "../0.Global.Foundation/module"
}

variable "resourceGroupName" {
  type = string
}

variable "openAI" {
  type = object(
    {
      regionName    = string
      accountName   = string
      domainName    = string
      serviceTier   = string
      enableStorage = bool
    }
  )
}

variable "appWorkflows" {
  type = list(object(
    {
      name = string
    }
  ))
}

variable "computeNetwork" {
  type = object(
    {
      name              = string
      subnetName        = string
      resourceGroupName = string
    }
  )
}

data "http" "client_address" {
  url = "https://api.ipify.org?format=json"
}

data "azurerm_user_assigned_identity" "studio" {
  name                = module.global.managedIdentity.name
  resource_group_name = module.global.resourceGroupName
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = module.global.resourceGroupName
    storage_account_name = module.global.rootStorage.accountName
    container_name       = module.global.rootStorage.containerName.terraform
    key                  = "1.Virtual.Network"
  }
}

data "azurerm_virtual_network" "compute" {
  name                = !local.stateExistsNetwork ? var.computeNetwork.name : data.terraform_remote_state.network.outputs.computeNetwork.name
  resource_group_name = !local.stateExistsNetwork ? var.computeNetwork.resourceGroupName : data.terraform_remote_state.network.outputs.resourceGroupName
}

data "azurerm_subnet" "farm" {
  name                 = !local.stateExistsNetwork ? var.computeNetwork.subnetName : data.terraform_remote_state.network.outputs.computeNetwork.subnets[data.terraform_remote_state.network.outputs.computeNetwork.subnetIndex.farm].name
  resource_group_name  = data.azurerm_virtual_network.compute.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.compute.name
}

data "azurerm_storage_account" "studio" {
  name                = module.global.rootStorage.accountName
  resource_group_name = module.global.resourceGroupName
}

locals {
  stateExistsNetwork = var.computeNetwork.name != "" ? false : try(length(data.terraform_remote_state.network.outputs) > 0, false)
}

resource "azurerm_resource_group" "ai" {
  name     = var.resourceGroupName
  location = var.openAI.regionName != "" ? var.openAI.regionName : module.global.regionName
}

resource "azurerm_private_dns_zone" "cognitive_services" {
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = azurerm_resource_group.ai.name
}

resource "azurerm_private_dns_zone" "open_ai" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = azurerm_resource_group.ai.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "cognitive_services" {
  name                  = "${data.azurerm_virtual_network.compute.name}.cognitive-services"
  resource_group_name   = azurerm_resource_group.ai.name
  private_dns_zone_name = azurerm_private_dns_zone.cognitive_services.name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "open_ai" {
  name                  = "${data.azurerm_virtual_network.compute.name}.open-ai"
  resource_group_name   = azurerm_resource_group.ai.name
  private_dns_zone_name = azurerm_private_dns_zone.open_ai.name
  virtual_network_id    = data.azurerm_virtual_network.compute.id
}

# resource "azurerm_private_endpoint" "cognitive_services" {
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
  custom_subdomain_name              = var.openAI.domainName != "" ? var.openAI.domainName : null
  sku_name                           = var.openAI.serviceTier
  kind                               = "OpenAI"
  public_network_access_enabled      = false
  outbound_network_access_restricted = false
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
  network_acls {
    default_action = "Deny"
    virtual_network_rules {
      subnet_id = data.azurerm_subnet.farm.id
    }
    ip_rules = [
      jsondecode(data.http.client_address.response_body).ip
    ]
  }
  dynamic storage {
    for_each = var.openAI.enableStorage ? [1] : []
    content {
      storage_account_id = data.azurerm_storage_account.studio.id
    }
  }
}

#################################################################################
# Logic Apps (https://learn.microsoft.com/azure/logic-apps/logic-apps-overview) #
#################################################################################

resource "azurerm_logic_app_workflow" "ai" {
  for_each = {
    for appWorkflow in var.appWorkflows : appWorkflow.name => appWorkflow
  }
  name                = each.value.name
  location            = azurerm_resource_group.ai.location
  resource_group_name = azurerm_resource_group.ai.name
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.studio.id
    ]
  }
}

output "resourceGroupName" {
  value = var.resourceGroupName
}

output "openAI" {
  value = azurerm_cognitive_account.open_ai.endpoint
}

output "appWorkflows" {
  value = [
    for appWorkflow in azurerm_logic_app_workflow.ai : {
      name     = appWorkflow.name
      endpoint = appWorkflow.access_endpoint
    }
  ]
}
