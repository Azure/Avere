// customize the simple VM by adjusting the following local variables
locals {
  // the region of the deployment
  location            = "eastus"
  vm_admin_username   = "azureuser"
  vm_admin_password   = "PASSWORD"
  resource_group_name = "resource_group"
  // set the following to true, otherwise use windows server
  use_windows_desktop = false

  // provide a globally unique name
  storage_account_name = "storageaccount"
  container_name       = "previz"
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

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_storage_container" "container" {
  name                  = local.container_name
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_virtual_network" "network" {
  name                = "example-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "vm" {
  name                = "publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = "example-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "artistmachine"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D4s_v3"
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  dynamic "source_image_reference" {
    for_each = local.use_windows_desktop == false ? ["MicrosoftWindowsServer"] : []
    content {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2016-Datacenter"
      version   = "latest"
    }
  }

  dynamic "source_image_reference" {
    for_each = local.use_windows_desktop == true ? ["MicrosoftWindowsDesktop"] : []
    content {
      publisher = "MicrosoftWindowsDesktop"
      offer     = "Windows-10"
      sku       = "19h2-pro"
      version   = "latest"
    }
  }
}

output "rdp_username" {
  value = local.vm_admin_username
}

output "rdp_address" {
  value = azurerm_public_ip.vm.ip_address
}

output "storage_account_container_sas_command_prefix" {
  value = "export SAS_PREFIX=https://${local.storage_account_name}.blob.core.windows.net/${local.container_name}?"
}

output "storage_account_container_sas_command_suffix" {
  value = "export SAS_SUFFIX=$(az storage container generate-sas --account-name ${local.storage_account_name} --https-only --permissions acdlrw --start 2020-04-06T00:00:00Z --expiry 2021-01-01T00:00:00Z --name ${local.container_name}  --output tsv)"
}
