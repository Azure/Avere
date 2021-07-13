/*
* Deploy a simulated on-prem network infrastructure:
* 1. VNET
* 2. Network Security Groups
* 3. Jumpbox
* 4. NFS Filer
* 5. VPN Gateway or VYOS Gateway
*/

#### Versions
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
  }
  backend "azurerm" {
    key = "onprem.tfstate"
  }
}

provider "azurerm" {
  features {}
}

### Variables
variable "onprem_location" {
  type = string
}

variable "onprem_rg" {
  type = string
}

variable "address_space" {
  type = string
}

variable "gateway_subnet" {
  type = string
}

variable "onprem_subnet_name" {
  type = string
}

variable "onprem_subnet" {
  type = string
}

variable "jumpbox_vm_size" {
  type = string
}

variable "vyos_image_id" {
  type = string
}

variable "vyos_static_private_ip_1" {
  type = string
}

variable "vyos_static_private_ip_2" {
  type = string
}

variable "vyos_asn" {
  type = string
}

variable "vm_admin_username" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "nfs_filer_vm_size" {
  type = string
}

variable "nfs_filer_unique_name" {
  type = string
}

variable "nfs_filer_fqdn" {
  type = string
}

variable "island_animation_sas_url" {
  description = "SAS url to Moana island animation sas url (https://www.disneyanimation.com/resources/moana-island-scene/)"
}

variable "island_basepackage_sas_url" {
  description = "SAS url to Moana island base package sas url (https://www.disneyanimation.com/resources/moana-island-scene/)"
}

variable "island_pbrt_sas_url" {
  description = "SAS url to Moana island PBRT sas url (https://www.disneyanimation.com/resources/moana-island-scene/)"
}

### Resources
data "azurerm_key_vault_secret" "virtualmachine" {
  name         = var.virtualmachine_key
  key_vault_id = var.key_vault_id
}

data "azurerm_key_vault_secret" "vpn_gateway_key" {
  name         = var.vpn_gateway_key
  key_vault_id = var.key_vault_id
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
  gateway_subnet_name = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? "vyossubnet" : "GatewaySubnet"
  ssh_port            = data.terraform_remote_state.network.outputs.ssh_port

  // azure gateway settings
  // generation and sku defined in https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark
  vpngw_generation = "Generation1"
  vpngw_sku        = "VpnGw2"

  // nfsfiler machine settings
  /*disk_size_gb = 127
  caching      = local.disk_size_gb > 4095 ? "None" : "ReadWrite"
  vm_size      = "Standard_F4s_v2"*/

  // vyos machine settings
  vyos_unique_name = "vyos"
  vyos_asn         = 64512

  azure_dns = "168.63.129.16"

  // jumpbox details
  vm_admin_username = var.vm_admin_username
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = data.azurerm_key_vault_secret.virtualmachine.value
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = var.ssh_public_key == "" ? null : var.ssh_public_key

  // to preserve single source of truth this comes from first element
  // of 1.network dns servers
  dns_static_private_ip = data.terraform_remote_state.network.outputs.onprem_dns_servers[0]
}

resource "azurerm_resource_group" "onpremrg" {
  name     = var.onprem_rg
  location = var.onprem_location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  resource_group_name = azurerm_resource_group.onpremrg.name
  location            = azurerm_resource_group.onpremrg.location
  address_space       = [var.address_space]
  dns_servers         = [local.dns_static_private_ip, local.azure_dns]

  tags = {
    // needed for DEVOPS testing
    SkipNRMSNSG = "12345"
  }
}

resource "azurerm_subnet" "gateway" {
  name                 = local.gateway_subnet_name
  resource_group_name  = azurerm_resource_group.onpremrg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.gateway_subnet]
}

resource "azurerm_subnet" "onprem" {
  name                 = var.onprem_subnet_name
  resource_group_name  = azurerm_resource_group.onpremrg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.onprem_subnet]
}

resource "azurerm_network_security_group" "onprem_nsg" {
  name                = "onprem_nsg"
  resource_group_name = azurerm_resource_group.onpremrg.name
  location            = azurerm_resource_group.onpremrg.location

  security_rule {
    name                       = "ssh"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = local.ssh_port
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "onprem" {
  subnet_id                 = azurerm_subnet.onprem.id
  network_security_group_id = azurerm_network_security_group.onprem_nsg.id
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
  vm_size                       = var.jumpbox_vm_size
  ssh_port                      = local.ssh_port

  // network details
  virtual_network_resource_group = azurerm_resource_group.onpremrg.name
  virtual_network_name           = azurerm_virtual_network.vnet.name
  virtual_network_subnet_name    = azurerm_subnet.onprem.name

  depends_on = [
    azurerm_resource_group.onpremrg,
    azurerm_subnet.onprem,
  ]
}

module "nfsfilerephemeral" {
  source              = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
  resource_group_name = azurerm_resource_group.onpremrg.name
  location            = azurerm_resource_group.onpremrg.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data
  vm_size             = var.nfs_filer_vm_size
  unique_name         = var.nfs_filer_unique_name

  // network details
  virtual_network_resource_group = azurerm_resource_group.onpremrg.name
  virtual_network_name           = azurerm_virtual_network.vnet.name
  virtual_network_subnet_name    = azurerm_subnet.onprem.name

  depends_on = [
    azurerm_subnet.onprem,
  ]
}

////////////////////////////////////////////////////////////////
// OnPrem DNS Server
//  - per the article: https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances?toc=/azure/dns/toc.json#vms-and-role-instances
//    use a single DNS server over Azure Private DNS because
//    we are connecting VNETs together
////////////////////////////////////////////////////////////////

module "dnsserver" {
  source              = "github.com/Azure/Avere/src/terraform/modules/dnsserver"
  resource_group_name = azurerm_resource_group.onpremrg.name
  location            = azurerm_resource_group.onpremrg.location
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data

  // network details
  virtual_network_resource_group = azurerm_resource_group.onpremrg.name
  virtual_network_name           = azurerm_virtual_network.vnet.name
  virtual_network_subnet_name    = azurerm_subnet.onprem.name

  // this is the address of the unbound dns server
  private_ip_address = local.dns_static_private_ip

  dns_server = local.azure_dns
  // these parameters should be named more generically, as they could be any generic core filer
  avere_address_list = [module.nfsfilerephemeral.primary_ip]
  avere_filer_fqdn   = var.nfs_filer_fqdn

  // set the TTL
  dns_max_ttl_seconds = 300

  depends_on = [
    module.nfsfilerephemeral,
  ]
}

module "download_moana" {
  source                     = "github.com/Azure/Avere/src/terraform/modules/download_moana"
  node_address               = module.jumpbox.jumpbox_address
  admin_username             = local.vm_admin_username
  admin_password             = local.vm_admin_password
  ssh_key_data               = local.vm_ssh_key_data
  ssh_port                   = local.ssh_port
  nfsfiler_address           = var.nfs_filer_fqdn
  nfsfiler_export_path       = module.nfsfilerephemeral.core_filer_export
  island_animation_sas_url   = var.island_animation_sas_url
  island_basepackage_sas_url = var.island_basepackage_sas_url
  island_pbrt_sas_url        = var.island_pbrt_sas_url

  depends_on = [
    module.nfsfilerephemeral,
    module.dnsserver,
    module.jumpbox,
  ]
}

////////////////////////////////////////////////////////////////
// Azure VPN Gateway Vnet2Vnet related resources
////////////////////////////////////////////////////////////////

resource "azurerm_public_ip" "onpremgatewaypublicip" {
  count               = data.terraform_remote_state.network.outputs.is_vnet_to_vnet ? 1 : 0
  name                = "onpremgatewaypublicip"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "vpngateway" {
  count               = data.terraform_remote_state.network.outputs.is_vnet_to_vnet ? 1 : 0
  name                = "onpremvpngateway"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = local.vpngw_generation
  sku        = local.vpngw_sku
  enable_bgp = true

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.onpremgatewaypublicip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  depends_on = [
    # the Azure vpn gateway creation will lock updates to the VNET
    # complete all vnet updates first
    azurerm_subnet_network_security_group_association.onprem
  ]
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_cloud" {
  count               = data.terraform_remote_state.network.outputs.is_vnet_to_vnet ? 1 : 0
  name                = "onprem_to_cloud"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.vpngateway[0].id
  peer_virtual_network_gateway_id = data.terraform_remote_state.network.outputs.vpn_gateway_id

  shared_key = data.azurerm_key_vault_secret.vpn_gateway_key.value
}

////////////////////////////////////////////////////////////////
// Azure VPN Gateway VPN IPSec related resources
////////////////////////////////////////////////////////////////

resource "azurerm_network_security_group" "vyos_nsg" {
  count               = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? 1 : 0
  name                = "vyos_nsg"
  resource_group_name = azurerm_resource_group.onpremrg.name
  location            = azurerm_resource_group.onpremrg.location

  security_rule {
    name                       = "cloudvpngwin"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = data.terraform_remote_state.network.outputs.vpn_gateway_public_ip_address
    destination_address_prefix = var.vyos_static_private_ip_1
  }

  # notice the required but counterintuitive source => destination
  security_rule {
    name                       = "remotevnetin"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = data.terraform_remote_state.network.outputs.cloud_address_space
  }

  security_rule {
    name                       = "remotevnetout"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = data.terraform_remote_state.network.outputs.cloud_address_space
  }

  security_rule {
    name                       = "remotevnetout2"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = data.terraform_remote_state.network.outputs.cloud_address_space
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "vyos" {
  count                     = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? 1 : 0
  subnet_id                 = azurerm_subnet.gateway.id
  network_security_group_id = azurerm_network_security_group.vyos_nsg[0].id
}

module "vyos_vm" {
  count               = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? 1 : 0
  source              = "github.com/Azure/Avere/src/terraform/modules/vyos_vm"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  ssh_key_data        = local.vm_ssh_key_data
  vyos_image_id       = var.vyos_image_id

  // network details
  static_private_ip = var.vyos_static_private_ip_1
  vnet_rg           = azurerm_resource_group.onpremrg.name
  vnet_name         = azurerm_virtual_network.vnet.name
  vnet_subnet_name  = azurerm_subnet.gateway.name

  depends_on = [
    azurerm_resource_group.onpremrg,
    azurerm_virtual_network.vnet,
    azurerm_subnet.gateway,
    # for security, delay the vyos vm creation until the security group is in place
    azurerm_subnet_network_security_group_association.vyos[0]
  ]
}

module "vyos_vm_connection" {
  count                  = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? 1 : 0
  source                 = "github.com/Azure/Avere/src/terraform/modules/vyos_vm_connection"
  vyos_vm_id             = module.vyos_vm[0].vm_id
  vpn_preshared_key      = data.azurerm_key_vault_secret.vpn_gateway_key.value
  vyos_vti_dummy_address = var.vyos_static_private_ip_2

  vyos_public_ip   = module.vyos_vm[0].public_ip_address
  vyos_bgp_address = module.vyos_vm[0].private_ip_address
  vyos_asn         = var.vyos_asn

  azure_vpn_gateway_public_ip   = data.terraform_remote_state.network.outputs.vpn_gateway_public_ip_address
  azure_vpn_gateway_bgp_address = data.terraform_remote_state.network.outputs.vpn_gateway_bgp_address
  azure_vpn_gateway_asn         = data.terraform_remote_state.network.outputs.vpn_gateway_asn

  depends_on = [module.vyos_vm]
}

resource "azurerm_route_table" "onpremroutable" {
  count               = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? 1 : 0
  name                = "onpremroutable"
  resource_group_name = azurerm_resource_group.onpremrg.name
  location            = azurerm_resource_group.onpremrg.location

  route {
    name                   = "onpremvyosguardroute"
    address_prefix         = data.terraform_remote_state.network.outputs.cloud_address_space
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.vyos_vm[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "onprem" {
  count          = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? 1 : 0
  subnet_id      = azurerm_subnet.onprem.id
  route_table_id = azurerm_route_table.onpremroutable[0].id
}

### Outputs
output "jumpbox_username" {
  value = module.jumpbox.jumpbox_username
}

output "jumpbox_address" {
  value = module.jumpbox.jumpbox_address
}

output "nfsfiler_username" {
  value = module.nfsfilerephemeral.admin_username
}

output "nfsfiler_fqdn" {
  value = var.nfs_filer_fqdn
}

output "nfsfiler_address" {
  value = module.nfsfilerephemeral.primary_ip
}

output "nfsfiler_export" {
  value = module.nfsfilerephemeral.core_filer_export
}

output "vyos_address" {
  value = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? module.vyos_vm[0].public_ip_address : ""
}

output "vyos_bgp_address" {
  value = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? module.vyos_vm[0].private_ip_address : ""
}

output "vyos_asn" {
  value = data.terraform_remote_state.network.outputs.is_vpn_ipsec ? local.vyos_asn : ""
}

output "onprem_location" {
  value = var.onprem_location
}

output "onprem_resource_group" {
  value = azurerm_resource_group.onpremrg.name
}

output "onprem_vpn_gateway_id" {
  value = data.terraform_remote_state.network.outputs.is_vnet_to_vnet ? azurerm_virtual_network_gateway.vpngateway[0].id : ""
}

output "onprem_address_space" {
  value = var.address_space
}

output "dns_server_ip" {
  value = local.dns_static_private_ip
}
