/*
* Create a connection to an oprem or simulated onprem VPN
*/

#### Versions
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.56.0"
    }
  }
  backend "azurerm" {
    key = "1.network.vpnconnection"
  }
}

provider "azurerm" {
  features {}
}

### Variables
variable "use_onprem_simulation" {
  type = bool
}

variable "real_onprem_address_space" {
  type = string
}

variable "real_onprem_vpn_address" {
  type = string
}

variable "real_onprem_vpn_bgp_address" {
  type = string
}

variable "real_onprem_vpn_asn" {
  type = string
}

### Resources
data "azurerm_key_vault_secret" "vpn_gateway_key" {
  name         = var.vpn_gateway_key
  key_vault_id = var.key_vault_id
}

# https://www.terraform.io/docs/language/settings/backends/azurerm.html#data-source-configuration
data "terraform_remote_state" "onprem" {
  count   = var.use_onprem_simulation ? 1 : 0
  backend = "azurerm"
  config = {
    key                  = "onprem.tfstate"
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.container_name
  }
}

# https://www.terraform.io/docs/language/settings/backends/azurerm.html#data-source-configuration
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    key                  = "1.network"
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.container_name
  }
}

locals {
  # setup the onprem local vars for convenience
  onprem_address_space   = var.use_onprem_simulation ? data.terraform_remote_state.onprem[0].outputs.onprem_address_space : var.real_onprem_address_space
  onprem_vpn_address     = var.use_onprem_simulation ? data.terraform_remote_state.onprem[0].outputs.vyos_address : var.real_onprem_vpn_address
  onprem_vpn_asn         = var.use_onprem_simulation ? data.terraform_remote_state.onprem[0].outputs.vyos_asn : var.real_onprem_vpn_asn
  onprem_vpn_bgp_address = var.use_onprem_simulation ? data.terraform_remote_state.onprem[0].outputs.vyos_bgp_address : var.real_onprem_vpn_bgp_address
}

# Vnet2Vnet
resource "azurerm_virtual_network_gateway_connection" "onprem_to_cloud" {
  count               = var.use_onprem_simulation && data.terraform_remote_state.onprem[0].outputs.deploy_azure_vpngw ? 1 : 0
  name                = "onprem_to_cloud"
  location            = data.terraform_remote_state.onprem[0].outputs.onprem_location
  resource_group_name = data.terraform_remote_state.onprem[0].outputs.onprem_resource_group

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = data.terraform_remote_state.onprem[0].outputs.onprem_vpn_gateway_id
  peer_virtual_network_gateway_id = data.terraform_remote_state.network.outputs.vpn_gateway_id

  shared_key = data.azurerm_key_vault_secret.vpn_gateway_key.value
}

resource "azurerm_virtual_network_gateway_connection" "cloud_to_onprem" {
  count               = var.use_onprem_simulation && data.terraform_remote_state.onprem[0].outputs.deploy_azure_vpngw ? 1 : 0
  name                = "cloud_to_onprem"
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.network_rg

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = data.terraform_remote_state.network.outputs.vpn_gateway_id
  peer_virtual_network_gateway_id = data.terraform_remote_state.onprem[0].outputs.onprem_vpn_gateway_id

  shared_key = data.azurerm_key_vault_secret.vpn_gateway_key.value
}

# Vnet to Onprem
resource "azurerm_local_network_gateway" "onpremise" {
  count               = var.use_onprem_simulation && data.terraform_remote_state.onprem[0].outputs.deploy_azure_vpngw ? 0 : 1
  name                = "onpremise"
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.network_rg
  gateway_address     = local.onprem_vpn_address
  address_space       = [local.onprem_address_space]
  bgp_settings {
    asn                 = local.onprem_vpn_asn
    bgp_peering_address = local.onprem_vpn_bgp_address
  }
}

resource "azurerm_virtual_network_gateway_connection" "onpremise" {
  count               = var.use_onprem_simulation && data.terraform_remote_state.onprem[0].outputs.deploy_azure_vpngw ? 0 : 1
  name                = "onpremise"
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.network_rg

  type                       = "IPsec"
  enable_bgp                 = true
  virtual_network_gateway_id = data.terraform_remote_state.network.outputs.vpn_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.onpremise[0].id

  shared_key = data.azurerm_key_vault_secret.vpn_gateway_key.value
}

### Outputs
