// customize the simple VM by adjusting the following local variables
locals {
  // the region of the deployment
  location          = "eastus"
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "P@$$w0rd1234!"

  unique_name = "unique"

  vm_size = "Standard_D2s_v3"

  resource_group_name = "windows_resource_group"

  // the following are the arguments to be passed to the custom script
  windows_custom_script_arguments = "$arguments = '-UserName ${local.vm_admin_username}' ; "

  // load the powershell file, you can substitute kv pairs as you need them, but 
  // use arguments where possible
  powershell_script = templatefile("${path.module}/setupMachine.ps1", {})
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

resource "azurerm_resource_group" "win" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  address_space       = ["10.0.0.0/24"]
  location            = azurerm_resource_group.win.location
  resource_group_name = azurerm_resource_group.win.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.win.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "vm" {
  name                = "${local.unique_name}-publicip"
  location            = local.location
  resource_group_name = azurerm_resource_group.win.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "vm" {
  name                = "${local.unique_name}-nic"
  location            = azurerm_resource_group.win.location
  resource_group_name = azurerm_resource_group.win.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "${local.unique_name}-vm"
  location              = azurerm_resource_group.win.location
  resource_group_name   = azurerm_resource_group.win.name
  computer_name         = local.unique_name
  custom_data           = base64gzip(local.powershell_script)
  admin_username        = local.vm_admin_username
  admin_password        = local.vm_admin_password
  size                  = local.vm_size
  network_interface_ids = [azurerm_network_interface.vm.id]

  os_disk {
    name                 = "${local.unique_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  /*source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }*/

  /*source_image_reference {
    publisher = "microsoftvisualstudio"
    offer     = "Windows"
    sku       = "Windows-10-N-x64"
    version   = "latest"
  }*/
}

locals {
  // the following powershell code will unzip and de-base64 the custom data payload enabling it
  // to be executed as a powershell script
  windows_custom_script_suffix = " $inputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomData.bin' ; $outputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomDataSetupScript.ps1' ; $inputStream = New-Object System.IO.FileStream $inputFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read) ; $sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)) ; $sr.ReadToEnd() | Out-File($outputFile) ; Invoke-Expression('{0} {1}' -f $outputFile, $arguments) ; "

  windows_custom_script = "powershell.exe -ExecutionPolicy Unrestricted -command \\\"${local.windows_custom_script_arguments} ${local.windows_custom_script_suffix}\\\""
}

resource "azurerm_virtual_machine_extension" "cse" {
  name                 = "${local.unique_name}-cse"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
        "commandToExecute": "${local.windows_custom_script} > %SYSTEMDRIVE%\\AzureData\\CustomDataSetupScript.log 2>&1"
    }
SETTINGS
}

output "username" {
  value = local.vm_admin_username
}

output "jumpbox_address" {
  value = azurerm_public_ip.vm.ip_address
}
