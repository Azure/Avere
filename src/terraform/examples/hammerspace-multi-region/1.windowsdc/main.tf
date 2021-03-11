// customize the simple VM by adjusting the following local variables
locals {
  // paste from 0.network output variables
  resource_group_unique_prefix = ""
  location1 = ""
  network-region1-jumpbox-subnet-id = ""

  // set the following variables to appropriate values

  resource_group_name = "${local.resource_group_unique_prefix}windc"
  unique_name = "dc"
  vm_size = "Standard_D4s_v3"
  # choose one of the following windows versions
  source_image_reference = local.windows_server_2016
  #source_image_reference = local.windows_server_2019
  # uncommenting below for win10 confirms an eligible Windows 10 license with multi-tenant hosting rights
  #source_image_reference = local.windows_10
  # choose the license_type
  license_type = "None"
  # license_type = "Windows_Client"
  # license_type = "Windows_Server"
  add_public_ip = true
  vm_admin_username = "azureuser"
  vm_admin_password = "ReplacePassword$"

  // network, set static and IP if using a DC
  use_static_private_ip_address = true
  private_ip_address = "10.0.3.254" // for example "10.0.3.254" could be use for domain controller

  // advanced: rarely changed parameters
  windows_server_2016 = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  windows_server_2019 = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

provider "azurerm" {
  version = "~>2.12.0"
  features {}
}

resource "azurerm_resource_group" "win" {
  name     = local.resource_group_name
  location = local.location1
}

resource "azurerm_public_ip" "vm" {
  name                         = "${local.unique_name}-publicip"
  location                     = local.location1
  resource_group_name          = azurerm_resource_group.win.name
  allocation_method            = "Static"

  count = local.add_public_ip ? 1 : 0
}

resource "azurerm_network_interface" "vm" {
  name                = "${local.unique_name}-nic"
  location            = azurerm_resource_group.win.location
  resource_group_name = azurerm_resource_group.win.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.network-region1-jumpbox-subnet-id
    private_ip_address_allocation = local.use_static_private_ip_address ? "Static" : "Dynamic"
    private_ip_address            = local.use_static_private_ip_address ? local.private_ip_address : null
    public_ip_address_id          = local.add_public_ip ? azurerm_public_ip.vm[0].id : ""
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "${local.unique_name}-vm"
  location              = azurerm_resource_group.win.location
  resource_group_name   = azurerm_resource_group.win.name
  computer_name         = local.unique_name
  admin_username        = local.vm_admin_username
  admin_password        = local.vm_admin_password
  size                  = local.vm_size
  network_interface_ids = [azurerm_network_interface.vm.id]
  license_type          = local.license_type
  
  os_disk {
    name                 = "${local.unique_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.source_image_reference.publisher
    offer     = local.source_image_reference.offer
    sku       = local.source_image_reference.sku
    version   = local.source_image_reference.version
  }
}

output "username" {
  value = local.vm_admin_username
}

output "vm_address" {
  value = "${local.add_public_ip ? azurerm_public_ip.vm[0].ip_address : azurerm_network_interface.vm.ip_configuration[0].private_ip_address}"
}