// customize the simple VM by editing the following local variables
locals {
  // auth details
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // leave ssh key data blank if you want to use a password
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."
  wg_vm_size      = "Standard_F32s_v2"
  jb_vm_size      = "Standard_D4s_v3"

  // region #1
  location1       = "eastus"
  resource_group1 = "region1-rg"
  unique_name1    = "region1"
  address_space1  = "10.0.0.0/16"
  gw_subnet1      = "10.0.0.0/24"
  render_subnet1  = "10.0.1.0/24"

  // region #2
  location2       = "westus2"
  resource_group2 = "region2-rg"
  unique_name2    = "region2"
  address_space2  = "10.1.0.0/16"
  gw_subnet2      = "10.1.0.0/24"
  render_subnet2  = "10.1.1.0/24"

  // wg cloud init
  wg_script_file_b64 = base64gzip(replace(file("${path.module}/wginstall.sh"), "\r", ""))
  wg_cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { installcmd = local.wg_script_file_b64 })
  // jb cloud init
  jb_script_file_b64 = base64gzip(replace(file("${path.module}/jbinstall.sh"), "\r", ""))
  jb_cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { installcmd = local.jb_script_file_b64 })
}

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

###########################################################
# Region 1 Network
###########################################################

resource "azurerm_resource_group" "region1rg" {
  name     = local.resource_group1
  location = local.location1
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "rendervnet1"
  resource_group_name = azurerm_resource_group.region1rg.name
  location            = azurerm_resource_group.region1rg.location
  address_space       = [local.address_space1]
}

resource "azurerm_subnet" "rendergwsubnet1" {
  // avoid reserved name "GatewaySubnet"
  name                 = "GWSubnet"
  resource_group_name  = azurerm_resource_group.region1rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = [local.gw_subnet1]
}

resource "azurerm_subnet" "rendernodes1" {
  name                 = "RenderNodes"
  resource_group_name  = azurerm_resource_group.region1rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = [local.render_subnet1]
}

// the following is only needed if you need to ssh to the controller
resource "azurerm_network_security_group" "ssh_nsg1" {
  name                = "ssh_nsg"
  location            = azurerm_resource_group.region1rg.location
  resource_group_name = azurerm_resource_group.region1rg.name

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
    name                       = "wireguard"
    priority                   = 121
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "51820"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowvnetin"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allowremotein"
    priority                   = 510
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = local.address_space2
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "denyallin"
    priority                   = 3000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "gw1" {
  subnet_id                 = azurerm_subnet.rendergwsubnet1.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg1.id
}

resource "azurerm_subnet_network_security_group_association" "render1" {
  subnet_id                 = azurerm_subnet.rendernodes1.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg1.id
}

# wireguard VM
resource "azurerm_public_ip" "wg1vm" {
  name                = "${local.unique_name1}-wg1publicip"
  resource_group_name = azurerm_resource_group.region1rg.name
  location            = azurerm_resource_group.region1rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "wg1vm" {
  name                = "${local.unique_name1}-wg1nic"
  resource_group_name = azurerm_resource_group.region1rg.name
  location            = azurerm_resource_group.region1rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.rendergwsubnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.wg1vm.id
  }
}

resource "azurerm_linux_virtual_machine" "wg1vm" {
  name                  = "${local.unique_name1}-wg1vm"
  resource_group_name   = azurerm_resource_group.region1rg.name
  location              = azurerm_resource_group.region1rg.location
  network_interface_ids = [azurerm_network_interface.wg1vm.id]
  computer_name         = "${local.unique_name1}-wg1vm"
  custom_data           = base64encode(local.wg_cloud_init_file)
  size                  = local.wg_vm_size

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  // by default the OS has encryption at rest
  os_disk {
    name                 = "${local.unique_name1}-wgosdisk"
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

resource "azurerm_virtual_machine_extension" "wg1cse" {
  name                 = "${local.unique_name1}-wg1cse"
  virtual_machine_id   = azurerm_linux_virtual_machine.wg1vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": " /bin/bash /opt/install.sh"
    }
SETTINGS
}

# linux jumpbox
resource "azurerm_public_ip" "jb1vm" {
  name                = "${local.unique_name1}-j1publicip"
  resource_group_name = azurerm_resource_group.region1rg.name
  location            = azurerm_resource_group.region1rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "jb1vm" {
  name                = "${local.unique_name1}-jb1nic"
  resource_group_name = azurerm_resource_group.region1rg.name
  location            = azurerm_resource_group.region1rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.rendergwsubnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jb1vm.id
  }
}

resource "azurerm_linux_virtual_machine" "jb1vm" {
  name                  = "${local.unique_name1}-jb1vm"
  resource_group_name   = azurerm_resource_group.region1rg.name
  location              = azurerm_resource_group.region1rg.location
  network_interface_ids = [azurerm_network_interface.jb1vm.id]
  computer_name         = "${local.unique_name1}-jb1vm"
  custom_data           = base64encode(local.jb_cloud_init_file)
  size                  = local.jb_vm_size

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  // by default the OS has encryption at rest
  os_disk {
    name                 = "${local.unique_name1}-jbosdisk"
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

resource "azurerm_virtual_machine_extension" "jb1cse" {
  name                 = "${local.unique_name1}-jb1cse"
  virtual_machine_id   = azurerm_linux_virtual_machine.jb1vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": " /bin/bash /opt/install.sh"
    }
SETTINGS
}

###########################################################
# Region 2 Network
###########################################################

resource "azurerm_resource_group" "region2rg" {
  name     = local.resource_group2
  location = local.location2
}

resource "azurerm_virtual_network" "vnet2" {
  name                = "rendervnet2"
  resource_group_name = azurerm_resource_group.region2rg.name
  location            = azurerm_resource_group.region2rg.location
  address_space       = [local.address_space2]
}

resource "azurerm_subnet" "rendergwsubnet2" {
  // avoid reserved name "GatewaySubnet"
  name                 = "GWSubnet"
  resource_group_name  = azurerm_resource_group.region2rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = [local.gw_subnet2]
}

resource "azurerm_subnet" "rendernodes2" {
  name                 = "RenderNodes"
  virtual_network_name = azurerm_virtual_network.vnet2.name
  resource_group_name  = azurerm_resource_group.region2rg.name
  address_prefixes     = [local.render_subnet2]
}

// the following is only needed if you need to ssh to the controller
resource "azurerm_network_security_group" "ssh_nsg2" {
  name                = "ssh_nsg"
  location            = azurerm_resource_group.region2rg.location
  resource_group_name = azurerm_resource_group.region2rg.name

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
    name                       = "wireguard"
    priority                   = 121
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "51820"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowremotein"
    priority                   = 510
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = local.address_space1
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "denyallin"
    priority                   = 3000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "gw2" {
  subnet_id                 = azurerm_subnet.rendergwsubnet2.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg2.id
}

resource "azurerm_subnet_network_security_group_association" "render2" {
  subnet_id                 = azurerm_subnet.rendernodes2.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg2.id
}

# wireguard VM
resource "azurerm_public_ip" "wg2vm" {
  name                = "${local.unique_name2}-wg1publicip"
  resource_group_name = azurerm_resource_group.region2rg.name
  location            = azurerm_resource_group.region2rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "wg2vm" {
  name                = "${local.unique_name2}-wg2nic"
  resource_group_name = azurerm_resource_group.region2rg.name
  location            = azurerm_resource_group.region2rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.rendergwsubnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.wg2vm.id
  }
}

resource "azurerm_linux_virtual_machine" "wg2vm" {
  name                  = "${local.unique_name2}-wg2vm"
  resource_group_name   = azurerm_resource_group.region2rg.name
  location              = azurerm_resource_group.region2rg.location
  network_interface_ids = [azurerm_network_interface.wg2vm.id]
  computer_name         = "${local.unique_name2}-wg2vm"
  custom_data           = base64encode(local.wg_cloud_init_file)
  size                  = local.wg_vm_size

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  // by default the OS has encryption at rest
  os_disk {
    name                 = "${local.unique_name2}-wgosdisk"
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

resource "azurerm_virtual_machine_extension" "wg2cse" {
  name                 = "${local.unique_name2}-wg1cse"
  virtual_machine_id   = azurerm_linux_virtual_machine.wg2vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": " /bin/bash /opt/install.sh"
    }
SETTINGS
}

# linux jumpbox
resource "azurerm_public_ip" "jb2vm" {
  name                = "${local.unique_name2}-j2publicip"
  resource_group_name = azurerm_resource_group.region2rg.name
  location            = azurerm_resource_group.region2rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "jb2vm" {
  name                = "${local.unique_name2}-jb2nic"
  resource_group_name = azurerm_resource_group.region2rg.name
  location            = azurerm_resource_group.region2rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.rendergwsubnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jb2vm.id
  }
}

resource "azurerm_linux_virtual_machine" "jb2vm" {
  name                  = "${local.unique_name2}-jb2vm"
  resource_group_name   = azurerm_resource_group.region2rg.name
  location              = azurerm_resource_group.region2rg.location
  network_interface_ids = [azurerm_network_interface.jb2vm.id]
  computer_name         = "${local.unique_name2}-jb2vm"
  custom_data           = base64encode(local.jb_cloud_init_file)
  size                  = local.jb_vm_size

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  // by default the OS has encryption at rest
  os_disk {
    name                 = "${local.unique_name2}-jbosdisk"
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

resource "azurerm_virtual_machine_extension" "jb2cse" {
  name                 = "${local.unique_name2}-jb2cse"
  virtual_machine_id   = azurerm_linux_virtual_machine.jb2vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": " /bin/bash /opt/install.sh"
    }
SETTINGS
}

output "wg1_public_address" {
  value = azurerm_public_ip.wg1vm.ip_address
}

output "wg1_private_address" {
  value = azurerm_network_interface.wg1vm.ip_configuration[0].private_ip_address
}

output "jb1_public_address" {
  value = azurerm_public_ip.jb1vm.ip_address
}

output "jb1_private_address" {
  value = azurerm_network_interface.jb1vm.ip_configuration[0].private_ip_address
}

output "wg2_public_address" {
  value = azurerm_public_ip.wg2vm.ip_address
}

output "wg2_private_address" {
  value = azurerm_network_interface.wg2vm.ip_configuration[0].private_ip_address
}

output "jb2_public_address" {
  value = azurerm_public_ip.jb2vm.ip_address
}

output "jb2_private_address" {
  value = azurerm_network_interface.jb2vm.ip_configuration[0].private_ip_address
}
