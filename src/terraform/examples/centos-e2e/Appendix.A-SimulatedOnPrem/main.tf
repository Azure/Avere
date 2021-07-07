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
      version = "~>2.56.0"
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

variable "vyos_image_id" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "disk_type" {
  type = string
}

variable "disk_size_gb" {
  type = number
}

### Resources
data "azurerm_key_vault_secret" "virtualmachine" {
  name         = var.virtualmachine_key
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
  gateway_subnet_name = var.vyos_image_id == "" ? "GatewaySubnet" : "vyossubnet"
  deploy_azure_vpngw  = var.vyos_image_id == ""

  // azure gateway settings
  // generation and sku defined in https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways#benchmark
  vpngw_generation = "Generation1"
  vpngw_sku        = "VpnGw2"

  // nfsfiler machine settings
  unique_name  = "onprem"
  disk_size_gb = 127
  caching      = local.disk_size_gb > 4095 ? "None" : "ReadWrite"
  vm_size      = "Standard_F4s_v2"

  // vyos machine settings
  vyos_vm_size     = "Standard_D2s_v3"
  vyos_unique_name = "vyos"
  vyos_asn         = 64512

  // jumpbox details
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = data.azurerm_key_vault_secret.virtualmachine.value
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = var.ssh_public_key == "" ? null : var.ssh_public_key
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

resource "azurerm_public_ip" "onpremgatewaypublicip" {
  name                = "onpremgatewaypublicip"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "vpngateway" {
  count               = local.deploy_azure_vpngw ? 1 : 0
  name                = "onpremvpngateway"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = local.vpngw_generation
  sku        = local.vpngw_sku
  enable_bgp = true

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.onpremgatewaypublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

resource "azurerm_public_ip" "vyos" {
  count               = local.deploy_azure_vpngw ? 0 : 1
  name                = "${local.vyos_unique_name}-publicip"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "vyosnic" {
  count               = local.deploy_azure_vpngw ? 0 : 1
  name                = "${local.vyos_unique_name}-nic"
  location            = azurerm_resource_group.onpremrg.location
  resource_group_name = azurerm_resource_group.onpremrg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.gateway.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vyos[0].id
  }
}

resource "azurerm_linux_virtual_machine" "vyos" {
  count                 = local.deploy_azure_vpngw ? 0 : 1
  name                  = local.vyos_unique_name
  resource_group_name   = azurerm_resource_group.onpremrg.name
  location              = azurerm_resource_group.onpremrg.location
  network_interface_ids = [azurerm_network_interface.vyosnic[0].id]
  computer_name         = local.vyos_unique_name
  size                  = local.vyos_vm_size

  source_image_id = var.vyos_image_id

  // by default the OS has encryption at rest
  os_disk {
    name                 = "osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  // configuration for authentication.  If ssh key specified, ignore password
  admin_username                  = local.vm_admin_username
  admin_password                  = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? local.vm_admin_password : null
  disable_password_authentication = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? false : true
  dynamic "admin_ssh_key" {
    for_each = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? [] : [local.vm_ssh_key_data]
    content {
      username   = local.vm_admin_username
      public_key = local.vm_ssh_key_data
    }
  }
}

resource "azurerm_network_security_group" "vyos_nsg" {
  count               = local.deploy_azure_vpngw ? 0 : 1
  name                = "vyos_nsg"
  resource_group_name = azurerm_resource_group.onpremrg.name
  location            = azurerm_resource_group.onpremrg.location

  security_rule {
    name                       = "ssh"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "cloudvpngw"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = data.terraform_remote_state.network.outputs.vpn_gateway_public_ip_address
    destination_address_prefix = "*"
  }
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
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vyos" {
  count                     = local.deploy_azure_vpngw ? 0 : 1
  subnet_id                 = azurerm_subnet.gateway.id
  network_security_group_id = azurerm_network_security_group.vyos_nsg[0].id
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
  storage_account_type = var.disk_type
  create_option        = "Empty"
  disk_size_gb         = var.disk_size_gb
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

### Outputs
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

output "vyos_address" {
  value = local.deploy_azure_vpngw ? "" : azurerm_public_ip.vyos[0].ip_address
}

output "vyos_bgp_address" {
  value = local.deploy_azure_vpngw ? "" : azurerm_network_interface.vyosnic[0].ip_configuration[0].private_ip_address
}

output "vyos_asn" {
  value = local.deploy_azure_vpngw ? "" : local.vyos_asn
}

output "cloud_bgp_address" {
  value = local.deploy_azure_vpngw ? "" : data.terraform_remote_state.network.outputs.vpn_gateway_bgp_addresses[0]
}

output "cloud_address_space" {
  value = local.deploy_azure_vpngw ? "" : data.terraform_remote_state.network.outputs.cloud_address_space
}

output "cloud_address" {
  value = local.deploy_azure_vpngw ? "" : data.terraform_remote_state.network.outputs.vpn_gateway_public_ip_address
}

output "cloud_asn" {
  value = local.deploy_azure_vpngw ? "" : data.terraform_remote_state.network.outputs.vpn_gateway_asn
}

output "onprem_location" {
  value = var.onprem_location
}

output "onprem_resource_group" {
  value = azurerm_resource_group.onpremrg.name
}

output "onprem_vpn_gateway_id" {
  value = local.deploy_azure_vpngw ? azurerm_virtual_network_gateway.vpngateway[0].id : ""
}

output "onprem_address_space" {
  value = var.address_space
}

output "deploy_azure_vpngw" {
  value = local.deploy_azure_vpngw
}
