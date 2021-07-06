/*
* Creates the Network infrastructure for cloud and onprem
* 1. Cloud Virtual Network and Subnet
* 2. Onprem Virtual Network and Subnet
* 3. Wireguard for cloud and onprem
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

variable "cloud_wg_public_key" {
  type = string
}

variable "cloud_wg_private_key" {
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

variable "onprem_vms_subnet_name" {
  type = string
}

variable "onprem_vms_subnet" {
  type = string
}

variable "onprem_wg_public_key" {
  type = string
}

variable "onprem_wg_private_key" {
  type      = string
  sensitive = true
}

variable "tunnel_count" {
  type = number
}

variable "base_udp_port" {
  type = number
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

variable "cloud_wg_vm_size" {
  type = string
}

variable "cloud_vm_size" {
  type = string
}

variable "onprem_wg_vm_size" {
  type = string
}

variable "onprem_vm_size" {
  type = string
}

variable "vmss_instance_count" {
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

  # the first 3 octet prefix of a non-overlapping range
  # use for wireguard interfadces
  dummy_ip_prefix = "10.255.255"
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

resource "azurerm_route_table" "cloudroutable" {
  name                = "cloudroutable"
  location            = azurerm_resource_group.cloud.location
  resource_group_name = azurerm_resource_group.cloud.name

  route {
    name                   = "cloudwireguardroute"
    address_prefix         = var.onprem_address_space
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.wireguardprimary.private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "cloud" {
  subnet_id      = azurerm_subnet.cloudvmssubnet.id
  route_table_id = azurerm_route_table.cloudroutable.id
}

resource "azurerm_network_security_group" "cloud_wg_nsg" {
  name                = "cloud_wg_nsg"
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location

  security_rule {
    name                       = "wireguard"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "UDP"
    source_port_range          = "*"
    destination_port_range     = var.tunnel_count > 1 ? "${var.base_udp_port}-${var.base_udp_port + (var.tunnel_count - 1)}" : var.base_udp_port
    source_address_prefix      = module.wireguardprimary.public_ip_address
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
    destination_address_prefix = var.onprem_address_space
  }
}

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
    destination_address_prefix = var.onprem_address_space
  }
}

resource "azurerm_subnet_network_security_group_association" "cloudwg" {
  subnet_id                 = azurerm_subnet.cloudgatewaysubnet.id
  network_security_group_id = azurerm_network_security_group.cloud_wg_nsg.id
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
    name                   = "onpremwireguardroute"
    address_prefix         = var.cloud_address_space
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.wireguardsecondary.private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "onprem" {
  subnet_id      = azurerm_subnet.onpremvmssubnet.id
  route_table_id = azurerm_route_table.onpremroutable.id
}

resource "azurerm_network_security_group" "onprem_wg_nsg" {
  name                = "onprem_wg_nsg"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location

  security_rule {
    name                       = "wireguard"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "UDP"
    source_port_range          = "*"
    destination_port_range     = var.tunnel_count > 1 ? "${var.base_udp_port}-${var.base_udp_port + (var.tunnel_count - 1)}" : var.base_udp_port
    source_address_prefix      = module.wireguardsecondary.public_ip_address
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

resource "azurerm_subnet_network_security_group_association" "onpremwg" {
  subnet_id                 = azurerm_subnet.onpremgatewaysubnet.id
  network_security_group_id = azurerm_network_security_group.onprem_wg_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "onpremvms" {
  subnet_id                 = azurerm_subnet.onpremvmssubnet.id
  network_security_group_id = azurerm_network_security_group.onprem_vms_nsg.id
}

# cloud wireguard Primary (cloud) VM
module "wireguardprimary" {
  source              = "github.com/Azure/Avere/src/terraform/modules/wireguard_vm"
  resource_group_name = azurerm_resource_group.cloud.name
  location            = azurerm_resource_group.cloud.location
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  ssh_key_data        = var.vm_ssh_key_data
  unique_name         = "cloud"
  vm_size             = var.cloud_wg_vm_size

  // network details
  vnet_rg          = azurerm_resource_group.cloud.name
  vnet_name        = var.cloud_vnet_name
  vnet_subnet_name = var.cloud_gateway_subnet_name

  depends_on = [azurerm_resource_group.cloud, azurerm_subnet.cloudgatewaysubnet]
}

module "wireguardprimaryconnection" {
  source                    = "github.com/Azure/Avere/src/terraform/modules/wireguard_vm_connection"
  wireguard_vm_id           = module.wireguardprimary.vm_id
  wireguard_private_key     = var.cloud_wg_private_key
  wireguard_peer_public_key = var.onprem_wg_public_key
  peer_public_address       = module.wireguardsecondary.public_ip_address
  peer_address_space        = [var.onprem_address_space]
  // this is the left side of the tunnel
  is_primary      = true
  dummy_ip_prefix = local.dummy_ip_prefix
  tunnel_count    = var.tunnel_count
  base_udp_port   = var.base_udp_port

  depends_on = [module.wireguardsecondary]
}

# cloud wireguard Secondary (onprem) VM
module "wireguardsecondary" {
  source              = "github.com/Azure/Avere/src/terraform/modules/wireguard_vm"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  ssh_key_data        = var.vm_ssh_key_data
  unique_name         = "onprem"
  vm_size             = var.onprem_wg_vm_size

  // network details
  vnet_rg          = azurerm_resource_group.onprem.name
  vnet_name        = var.onprem_vnet_name
  vnet_subnet_name = var.onprem_gateway_subnet_name

  depends_on = [azurerm_resource_group.onprem, azurerm_subnet.onpremgatewaysubnet]
}

module "wireguardsecondaryconnection" {
  source                    = "github.com/Azure/Avere/src/terraform/modules/wireguard_vm_connection"
  wireguard_vm_id           = module.wireguardsecondary.vm_id
  wireguard_private_key     = var.onprem_wg_private_key
  wireguard_peer_public_key = var.cloud_wg_public_key
  peer_public_address       = module.wireguardprimary.public_ip_address
  peer_address_space        = [var.cloud_address_space]
  is_primary                = false
  dummy_ip_prefix           = local.dummy_ip_prefix
  tunnel_count              = var.tunnel_count
  base_udp_port             = var.base_udp_port

  depends_on = [module.wireguardprimary]
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

# cloud VMSS
resource "azurerm_linux_virtual_machine_scale_set" "cloudvmss" {
  name                            = "cloudvmss"
  resource_group_name             = azurerm_resource_group.cloud.name
  location                        = azurerm_resource_group.cloud.location
  sku                             = var.cloud_vm_size
  instances                       = var.vmss_instance_count
  admin_username                  = var.vm_admin_username
  admin_password                  = (var.vm_ssh_key_data == null || var.vm_ssh_key_data == "") && var.vm_admin_password != null && var.vm_admin_password != "" ? var.vm_admin_password : null
  disable_password_authentication = (var.vm_ssh_key_data == null || var.vm_ssh_key_data == "") && var.vm_admin_password != null && var.vm_admin_password != "" ? false : true
  custom_data                     = base64encode(local.init_file)

  source_image_reference {
    publisher = local.source_image_vm.publisher
    offer     = local.source_image_vm.offer
    sku       = local.source_image_vm.sku
    version   = local.source_image_vm.version
  }

  // avoid overprovision as it can create race conditions with render managers
  overprovision = false
  // avoid use of zones so you get maximum spread of machines, and have > 100 nodes
  single_placement_group = false
  // avoid use of zones so you get maximum spread of machines
  zone_balance = false
  zones        = []
  // avoid use proximity groups so you get maximum spread of machines
  // proximity_placement_group_id

  dynamic "admin_ssh_key" {
    for_each = var.vm_ssh_key_data == null || var.vm_ssh_key_data == "" ? [] : [var.vm_ssh_key_data]
    content {
      username   = var.vm_admin_username
      public_key = var.vm_ssh_key_data
    }
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }


  network_interface {
    name                          = "cloudvmssnic"
    primary                       = true
    enable_accelerated_networking = false

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.cloudvmssubnet.id
    }
  }

  extension {
    name                 = "cloudvmsscse"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    settings = <<SETTINGS
    {
        "commandToExecute": " /bin/bash /opt/install.sh"
    }
SETTINGS
  }
}

# onprem VMSS
# cloud VMSS
resource "azurerm_linux_virtual_machine_scale_set" "onpremvmss" {
  name                            = "onpremvmss"
  resource_group_name             = azurerm_resource_group.onprem.name
  location                        = azurerm_resource_group.onprem.location
  sku                             = var.onprem_vm_size
  instances                       = var.vmss_instance_count
  admin_username                  = var.vm_admin_username
  admin_password                  = (var.vm_ssh_key_data == null || var.vm_ssh_key_data == "") && var.vm_admin_password != null && var.vm_admin_password != "" ? var.vm_admin_password : null
  disable_password_authentication = (var.vm_ssh_key_data == null || var.vm_ssh_key_data == "") && var.vm_admin_password != null && var.vm_admin_password != "" ? false : true
  custom_data                     = base64encode(local.init_file)

  source_image_reference {
    publisher = local.source_image_vm.publisher
    offer     = local.source_image_vm.offer
    sku       = local.source_image_vm.sku
    version   = local.source_image_vm.version
  }

  // avoid overprovision as it can create race conditions with render managers
  overprovision = false
  // avoid use of zones so you get maximum spread of machines, and have > 100 nodes
  single_placement_group = false
  // avoid use of zones so you get maximum spread of machines
  zone_balance = false
  zones        = []
  // avoid use proximity groups so you get maximum spread of machines
  // proximity_placement_group_id

  dynamic "admin_ssh_key" {
    for_each = var.vm_ssh_key_data == null || var.vm_ssh_key_data == "" ? [] : [var.vm_ssh_key_data]
    content {
      username   = var.vm_admin_username
      public_key = var.vm_ssh_key_data
    }
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }


  network_interface {
    name                          = "onpremvmssnic"
    primary                       = true
    enable_accelerated_networking = false

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.onpremvmssubnet.id
    }
  }

  extension {
    name                 = "onpremvmsscse"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    settings = <<SETTINGS
    {
        "commandToExecute": " /bin/bash /opt/install.sh"
    }
SETTINGS
  }
}

### Outputs
output "cloud_location" {
  value = var.cloud_location
}

output "onprem_location" {
  value = var.onprem_location
}

output "vm_admin_username" {
  value = var.vm_admin_username
}

output "cloud_wireguard_public_ip_address" {
  value = module.wireguardprimary.public_ip_address
}

output "cloud_wireguard_private_ip_address" {
  value = module.wireguardprimary.private_ip_address
}

output "onprem_wireguard_public_ip_address" {
  value = module.wireguardsecondary.public_ip_address
}

output "onprem_wireguard_private_ip_address" {
  value = module.wireguardsecondary.private_ip_address
}

output "cloud_vm_public_ip_address" {
  value = azurerm_public_ip.cloudvm.ip_address
}

output "onprem_vm_public_ip_address" {
  value = azurerm_public_ip.onpremvm.ip_address
}

output "cloudvmss_addresses_command" {
  // local-exec doesn't return output, and the only way to 
  // try to get the output is follow advice from https://stackoverflow.com/questions/49136537/obtain-ip-of-internal-load-balancer-in-app-service-environment/49436100#49436100
  // in the meantime just provide the az cli command to
  // the customer
  value = "az vmss nic list -g ${azurerm_resource_group.cloud.name} --vmss-name ${azurerm_linux_virtual_machine_scale_set.cloudvmss.name} --query \"[].ipConfigurations[].privateIpAddress\""
}

output "onpremvmss_addresses_command" {
  // local-exec doesn't return output, and the only way to 
  // try to get the output is follow advice from https://stackoverflow.com/questions/49136537/obtain-ip-of-internal-load-balancer-in-app-service-environment/49436100#49436100
  // in the meantime just provide the az cli command to
  // the customer
  value = "az vmss nic list -g ${azurerm_resource_group.onprem.name} --vmss-name ${azurerm_linux_virtual_machine_scale_set.onpremvmss.name} --query \"[].ipConfigurations[].privateIpAddress\""
}
