data "azurerm_key_vault" "keyvault" {
  name                = local.keyvault_name
  resource_group_name = local.keyvault_resource_group_name
}

data "azurerm_key_vault_secret" "virtualmachine" {
  name         = "virtualmachine"
  key_vault_id = data.azurerm_key_vault.keyvault.id
}

// customize the simple VM by editing the following local variables
locals {
  location                     = ""
  keyvault_name                = "renderkeyvault"
  keyvault_resource_group_name = "keyvault_rg"

  onprem_simulated_resource_group_name = "onprem_rg"

  // virtual network settings
  address_space = "172.16.0.0/23"
  // DO NOT CHANGE NAME "GatewaySubnet", Azure requires it with that name
  gateway_subnet_name = "GatewaySubnet"
  gateway_subnet      = "172.16.0.0/24"
  onprem_subnet_name  = "onprem"
  onprem_subnet       = "172.16.1.0/24"

  // vnet to vnet settings
  vpngw_generation = "Generation1" // generation and sku defined in https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark
  vpngw_sku        = "VpnGw2"

  unique_name  = "onprem"
  disk_size_gb = 127
  caching      = local.disk_size_gb > 4095 ? "None" : "ReadWrite"
  vm_size      = "Standard_F4s_v2"

  // jumpbox details
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = data.azurerm_key_vault_secret.virtualmachine.value
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
}

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "onpremrg" {
  name     = local.onprem_simulated_resource_group_name
  location = local.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  resource_group_name = azurerm_resource_group.onpremrg.name
  location            = azurerm_resource_group.onpremrg.location
  address_space       = [local.address_space]
}

resource "azurerm_subnet" "gateway" {
  name                 = local.gateway_subnet_name
  resource_group_name  = azurerm_resource_group.onpremrg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.gateway_subnet]
}

resource "azurerm_subnet" "onprem" {
  name                 = local.onprem_subnet_name
  resource_group_name  = azurerm_resource_group.onpremrg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.onprem_subnet]
}

resource "azurerm_public_ip" "onpremgatewaypublicip" {
  name                = "onpremgatewaypublicip"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "vpngateway" {
  name                = "onpremvpngateway"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = local.vpngw_generation
  sku        = local.vpngw_sku

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.onpremgatewaypublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

module "jumpbox" {
  source                        = "github.com/Azure/Avere/src/terraform/modules/jumpbox"
  resource_group_name           = azurerm_resource_group.onpremrg.name
  location                      = azurerm_resource_group.onpremrg.location
  admin_username                = local.vm_admin_username
  admin_password                = local.vm_admin_password
  ssh_key_data                  = local.vm_ssh_key_data
  add_public_ip                 = true
  build_vfxt_terraform_provider = false

  // network details
  virtual_network_resource_group = azurerm_resource_group.onpremrg.name
  virtual_network_name           = azurerm_virtual_network.vnet.name
  virtual_network_subnet_name    = azurerm_subnet.onprem.name

  depends_on = [
    azurerm_resource_group.onpremrg,
    azurerm_subnet.onprem,
  ]
}

resource "azurerm_managed_disk" "nfsfiler" {
  name                 = "${local.unique_name}-disk1"
  resource_group_name  = azurerm_resource_group.onpremrg.name
  location             = azurerm_resource_group.onpremrg.location
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = local.disk_size_gb
}

module "nfsfiler" {
  source              = "github.com/Azure/Avere/src/terraform/modules/nfs_filer_md"
  resource_group_name = azurerm_resource_group.onpremrg.name
  location            = azurerm_resource_group.onpremrg.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data
  vm_size             = local.vm_size
  unique_name         = local.unique_name
  caching             = local.caching
  managed_disk_id     = azurerm_managed_disk.nfsfiler.id

  // network details
  virtual_network_resource_group = azurerm_resource_group.onpremrg.name
  virtual_network_name           = azurerm_virtual_network.vnet.name
  virtual_network_subnet_name    = azurerm_subnet.onprem.name

  depends_on = [
    azurerm_managed_disk.nfsfiler,
    azurerm_subnet.onprem,
  ]
}

output "jumpbox_username" {
  value = module.jumpbox.jumpbox_username
}

output "jumpbox_address" {
  value = module.jumpbox.jumpbox_address
}

output "nfsfiler_username" {
  value = module.nfsfiler.admin_username
}

output "nfsfiler_address" {
  value = module.nfsfiler.primary_ip
}

output "onprem_location" {
  value = local.location
}

output "onprem_resource_group" {
  value = azurerm_resource_group.onpremrg.name
}

output "onprem_vpn_gateway_id" {
  value = azurerm_virtual_network_gateway.vpngateway.id
}
