/*
* Creates the Network infrastructure for cloud and onprem
* 1. Cloud Virtual Network and Subnet
* 2. Onprem Virtual Network and Subnet
* 3. Cloud VPN Gateway
* 4. VvOS VM for On-premises
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
}

provider "azurerm" {
  features {}
}

### Variables
variable "cloud_location" {
  type = string
}

variable "cloud_network_rg" {
  type = string
}

variable "cloud_vnet_name" {
  type = string
}

variable "cloud_address_space" {
  type = string
}

variable "cloud_gateway_subnet_name" {
  type = string
}

variable "cloud_gateway_subnet" {
  type = string
}

variable "cloud_vms_subnet_name" {
  type = string
}

variable "cloud_vms_subnet" {
  type = string
}

variable "vpngw_generation" {
  type = string
}

variable "vpngw_sku" {
  type = string
}

variable "vpn_secret_key" {
  type      = string
  sensitive = true
}

variable "onprem_location" {
  type = string
}

variable "onprem_network_rg" {
  type = string
}

variable "onprem_vnet_name" {
  type = string
}

variable "onprem_address_space" {
  type = string
}

variable "onprem_gateway_subnet_name" {
  type = string
}

variable "onprem_gateway_subnet" {
  type = string
}

variable "onprem_gateway_static_ip1" {
  type = string
}

variable "onprem_gateway_static_ip2" {
  type = string
}

variable "onprem_vms_subnet_name" {
  type = string
}

variable "onprem_vms_subnet" {
  type = string
}

variable "vm_admin_username" {
  type = string
}

variable "vm_admin_password" {
  type      = string
  sensitive = true
}

variable "vm_ssh_key_data" {
  type = string
}

variable "cloud_vm_size" {
  type = string
}

variable "onprem_vyos_vm_size" {
  type = string
}

variable "onprem_vm_size" {
  type = string
}

variable "vyos_image_id" {
  type = string
}

variable "onprem_vpn_asn" {
  type = number
}

### Resources
locals {
  script_file_b64 = base64gzip(replace(file("${path.module}/install.sh"), "\r", ""))
  init_file       = templatefile("${path.module}/cloud-init.tpl", { installcmd = local.script_file_b64 })

  source_image_vm = local.source_image_ubuntu_20_04_LTS_focal

  source_image_ubuntu_20_04_LTS_focal = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

resource "azurerm_resource_group" "cloud" {
  name     = var.cloud_network_rg
  location = var.cloud_location
}

resource "azurerm_virtual_network" "cloudvnet" {
  name                = var.cloud_vnet_name
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location
  address_space       = [var.cloud_address_space]
}

resource "azurerm_subnet" "cloudgatewaysubnet" {
  name                 = var.cloud_gateway_subnet_name
  resource_group_name  = azurerm_resource_group.cloud.name
  virtual_network_name = azurerm_virtual_network.cloudvnet.name
  address_prefixes     = [var.cloud_gateway_subnet]
}

resource "azurerm_subnet" "cloudvmssubnet" {
  name                 = var.cloud_vms_subnet_name
  resource_group_name  = azurerm_resource_group.cloud.name
  virtual_network_name = azurerm_virtual_network.cloudvnet.name
  address_prefixes     = [var.cloud_vms_subnet]
}

// the following is only needed if you need to ssh to the controller
resource "azurerm_network_security_group" "cloud_vms_nsg" {
  name                = "cloud_vms_nsg"
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location

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

resource "azurerm_subnet_network_security_group_association" "cloudvms" {
  subnet_id                 = azurerm_subnet.cloudvmssubnet.id
  network_security_group_id = azurerm_network_security_group.cloud_vms_nsg.id
}

resource "azurerm_resource_group" "onprem" {
  name     = var.onprem_network_rg
  location = var.onprem_location
}

resource "azurerm_virtual_network" "onpremvnet" {
  name                = var.onprem_vnet_name
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  address_space       = [var.onprem_address_space]
}

resource "azurerm_subnet" "onpremgatewaysubnet" {
  name                 = var.onprem_gateway_subnet_name
  resource_group_name  = azurerm_resource_group.onprem.name
  virtual_network_name = azurerm_virtual_network.onpremvnet.name
  address_prefixes     = [var.onprem_gateway_subnet]
}

resource "azurerm_subnet" "onpremvmssubnet" {
  name                 = var.onprem_vms_subnet_name
  resource_group_name  = azurerm_resource_group.onprem.name
  virtual_network_name = azurerm_virtual_network.onpremvnet.name
  address_prefixes     = [var.onprem_vms_subnet]
}

resource "azurerm_route_table" "onpremroutable" {
  name                = "onpremroutable"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name

  route {
    name                   = "onpremvyosguardroute"
    address_prefix         = var.cloud_address_space
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.vyos_vm.private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "onprem" {
  subnet_id      = azurerm_subnet.onpremvmssubnet.id
  route_table_id = azurerm_route_table.onpremroutable.id
}

resource "azurerm_network_security_group" "onprem_vyos_nsg" {
  name                = "onprem_vyos_nsg"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location

  security_rule {
    name                       = "remotevpnin"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_virtual_network_gateway.cloudvpngw.bgp_settings[0].peering_addresses[0].tunnel_ip_addresses[0]
    destination_address_prefix = var.onprem_gateway_static_ip1
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
    destination_address_prefix = var.cloud_address_space
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
    destination_address_prefix = var.cloud_address_space
  }

  security_rule {
    name                       = "remotevnetout2"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.cloud_address_space
    destination_address_prefix = "VirtualNetwork"
  }

  depends_on = [
    # the gateway must be created first
    azurerm_virtual_network_gateway.cloudvpngw
  ]
}

resource "azurerm_network_security_group" "onprem_vms_nsg" {
  name                = "onprem_vms_nsg"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location

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

  # notice the required but counterintuitive source => destination
  security_rule {
    name                       = "remotevnetin"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = var.cloud_address_space
  }
}

resource "azurerm_subnet_network_security_group_association" "onpremvyos" {
  subnet_id                 = azurerm_subnet.onpremgatewaysubnet.id
  network_security_group_id = azurerm_network_security_group.onprem_vyos_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "onpremvms" {
  subnet_id                 = azurerm_subnet.onpremvmssubnet.id
  network_security_group_id = azurerm_network_security_group.onprem_vms_nsg.id
}

# VPN Gateway
resource "azurerm_public_ip" "cloudgwpublicip" {
  name                = "cloudgwpublicip"
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "cloudvpngw" {
  name                = "cloudvpngw"
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location

  type       = "Vpn"
  vpn_type   = "RouteBased"
  generation = var.vpngw_generation
  sku        = var.vpngw_sku
  enable_bgp = true

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.cloudgwpublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.cloudgatewaysubnet.id
  }

  depends_on = [
    # vpn gateway blocks NSG creation, wait until complete
    azurerm_subnet_network_security_group_association.cloudvms,
    azurerm_subnet_network_security_group_association.onpremvms,
  ]
}

resource "azurerm_local_network_gateway" "onpremise" {
  name                = "onpremise"
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location
  gateway_address     = module.vyos_vm.public_ip_address
  address_space       = [var.onprem_address_space]
  bgp_settings {
    asn                 = var.onprem_vpn_asn
    bgp_peering_address = module.vyos_vm.private_ip_address
  }
}

resource "azurerm_virtual_network_gateway_connection" "onpremise" {
  name                = "onpremise"
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location

  type                       = "IPsec"
  enable_bgp                 = true
  virtual_network_gateway_id = azurerm_virtual_network_gateway.cloudvpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.onpremise.id

  shared_key = var.vpn_secret_key
}

# VyOS VM
module "vyos_vm" {
  source              = "github.com/Azure/Avere/src/terraform/modules/vyos_vm"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  ssh_key_data        = var.vm_ssh_key_data
  unique_name         = "vyos"
  vm_size             = var.onprem_vyos_vm_size
  vyos_image_id       = var.vyos_image_id

  // network details
  static_private_ip = var.onprem_gateway_static_ip1
  vnet_rg           = azurerm_resource_group.onprem.name
  vnet_name         = var.onprem_vnet_name
  vnet_subnet_name  = var.onprem_gateway_subnet_name

  depends_on = [
    # for security, delay the vyos vm creation until the security group is in place
    azurerm_subnet_network_security_group_association.onpremvyos
  ]
}

module "vyos_vm_connection" {
  source                 = "github.com/Azure/Avere/src/terraform/modules/vyos_vm_connection"
  vyos_vm_id             = module.vyos_vm.vm_id
  vpn_preshared_key      = var.vpn_secret_key
  vyos_vti_dummy_address = var.onprem_gateway_static_ip2

  vyos_public_ip   = module.vyos_vm.public_ip_address
  vyos_bgp_address = module.vyos_vm.private_ip_address
  vyos_asn         = var.onprem_vpn_asn

  azure_vpn_gateway_public_ip   = azurerm_virtual_network_gateway.cloudvpngw.bgp_settings[0].peering_addresses[0].tunnel_ip_addresses[0]
  azure_vpn_gateway_bgp_address = azurerm_virtual_network_gateway.cloudvpngw.bgp_settings[0].peering_addresses[0].default_addresses[0]
  azure_vpn_gateway_asn         = azurerm_virtual_network_gateway.cloudvpngw.bgp_settings[0].asn

  depends_on = [module.vyos_vm]
}

# cloud vm
resource "azurerm_public_ip" "cloudvm" {
  name                = "cloudvmpublicip"
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "cloudvm" {
  name                = "cloudvmnic"
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cloudvmssubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cloudvm.id
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.cloudvms
  ]
}

resource "azurerm_linux_virtual_machine" "cloudvm" {
  name                  = "cloudvm"
  resource_group_name   = azurerm_resource_group.cloud.name
  location              = azurerm_resource_group.cloud.location
  network_interface_ids = [azurerm_network_interface.cloudvm.id]
  computer_name         = "cloudvm"
  custom_data           = base64encode(local.init_file)
  size                  = var.cloud_vm_size

  source_image_reference {
    publisher = local.source_image_vm.publisher
    offer     = local.source_image_vm.offer
    sku       = local.source_image_vm.sku
    version   = local.source_image_vm.version
  }

  os_disk {
    name                 = "cloudvmosdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  // configuration for authentication.  If ssh key specified, ignore password
  admin_username                  = var.vm_admin_username
  admin_password                  = (var.vm_ssh_key_data == null || var.vm_ssh_key_data == "") && var.vm_admin_password != null && var.vm_admin_password != "" ? var.vm_admin_password : null
  disable_password_authentication = (var.vm_ssh_key_data == null || var.vm_ssh_key_data == "") && var.vm_admin_password != null && var.vm_admin_password != "" ? false : true
  dynamic "admin_ssh_key" {
    for_each = var.vm_ssh_key_data == null || var.vm_ssh_key_data == "" ? [] : [var.vm_ssh_key_data]
    content {
      username   = var.vm_admin_username
      public_key = var.vm_ssh_key_data
    }
  }
}

resource "azurerm_virtual_machine_extension" "cloudvmcse" {
  name                 = "cloudvmcse"
  virtual_machine_id   = azurerm_linux_virtual_machine.cloudvm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": " /bin/bash /opt/install.sh"
    }
SETTINGS
}

# on prem vm
resource "azurerm_public_ip" "onpremvm" {
  name                = "onpremvmpublicip"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "onpremvm" {
  name                = "onpremvmnic"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onpremvmssubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onpremvm.id
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.onpremvms
  ]
}

resource "azurerm_linux_virtual_machine" "onpremvm" {
  name                  = "onpremvm"
  resource_group_name   = azurerm_resource_group.onprem.name
  location              = azurerm_resource_group.onprem.location
  network_interface_ids = [azurerm_network_interface.onpremvm.id]
  computer_name         = "onpremvm"
  custom_data           = base64encode(local.init_file)
  size                  = var.onprem_vm_size

  source_image_reference {
    publisher = local.source_image_vm.publisher
    offer     = local.source_image_vm.offer
    sku       = local.source_image_vm.sku
    version   = local.source_image_vm.version
  }

  os_disk {
    name                 = "onpremvmosdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  // configuration for authentication.  If ssh key specified, ignore password
  admin_username                  = var.vm_admin_username
  admin_password                  = (var.vm_ssh_key_data == null || var.vm_ssh_key_data == "") && var.vm_admin_password != null && var.vm_admin_password != "" ? var.vm_admin_password : null
  disable_password_authentication = (var.vm_ssh_key_data == null || var.vm_ssh_key_data == "") && var.vm_admin_password != null && var.vm_admin_password != "" ? false : true
  dynamic "admin_ssh_key" {
    for_each = var.vm_ssh_key_data == null || var.vm_ssh_key_data == "" ? [] : [var.vm_ssh_key_data]
    content {
      username   = var.vm_admin_username
      public_key = var.vm_ssh_key_data
    }
  }
}

resource "azurerm_virtual_machine_extension" "onpremvmcse" {
  name                 = "onpremvmcse"
  virtual_machine_id   = azurerm_linux_virtual_machine.onpremvm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": " /bin/bash /opt/install.sh"
    }
SETTINGS
}

### Outputs
output "cloud_location" {
  value = var.cloud_location
}

output "cloud_vm_public_ip_address" {
  value = azurerm_public_ip.cloudvm.ip_address
}

output "cloud_vpn_gateway_public_ip_address" {
  value = azurerm_virtual_network_gateway.cloudvpngw.bgp_settings[0].peering_addresses[0].tunnel_ip_addresses[0]
}

output "cloud_vpn_gateway_asn" {
  value = azurerm_virtual_network_gateway.cloudvpngw.bgp_settings[0].asn
}

output "cloud_vpn_gateway_bgp_addresses" {
  value = azurerm_virtual_network_gateway.cloudvpngw.bgp_settings[0].peering_addresses[0].default_addresses
}

output "onprem_location" {
  value = var.onprem_location
}

output "vm_admin_username" {
  value = var.vm_admin_username
}

output "onprem_vyos_public_ip_address" {
  value = module.vyos_vm.public_ip_address
}

output "onprem_vyos_private_ip_address" {
  value = module.vyos_vm.private_ip_address
}

output "onprem_vm_public_ip_address" {
  value = azurerm_public_ip.onpremvm.ip_address
}
