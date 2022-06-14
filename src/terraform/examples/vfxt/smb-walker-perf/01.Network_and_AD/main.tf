////////////////////////////////////////////////////////////////////////////////////////
// WARNING: if you get an error deploying, please review https://aka.ms/avere-tf-prereqs
////////////////////////////////////////////////////////////////////////////////////////
locals {
  // the region of the deployment
  location          = "eastus"
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  ssh_port        = 2022
  rdp_port        = 5555

  // network details
  network_resource_group_name = "smb_test_network_resource_group"

  open_external_ports = [local.ssh_port, local.rdp_port]
  // for a fully locked down internet get your external IP address from http://www.myipaddress.com/
  // or if accessing from cloud shell, put "AzureCloud"
  open_external_sources = ["*"]
  peer_vnet_rg          = ""
  peer_vnet_name        = ""

  # Windows VM for DC set up
  windows_rg = "smb_test_window_dc"
  // the following are the arguments to be passed to the custom script
  windows_custom_script_arguments = "$arguments = '-RdpPort ${local.rdp_port}' ; "

  // load the powershell file, you can substitute kv pairs as you need them, but 
  // use arguments where possible
  powershell_script = templatefile("${path.module}/setupMachine.ps1", {})

  // the following powershell code will unzip and de-base64 the custom data payload enabling it
  // to be executed as a powershell script
  windows_custom_script_suffix = " $inputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomData.bin' ; $outputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomDataSetupScript.ps1' ; $inputStream = New-Object System.IO.FileStream $inputFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read) ; $sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)) ; $sr.ReadToEnd() | Out-File($outputFile) ; Invoke-Expression('{0} {1}' -f $outputFile, $arguments) ; "

  windows_custom_script = "powershell.exe -ExecutionPolicy Unrestricted -command \\\"${local.windows_custom_script_arguments} ${local.windows_custom_script_suffix}\\\""
}

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.66.0"
    }
    avere = {
      source  = "hashicorp/avere"
      version = ">=1.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

// the render network
module "network" {
  source              = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_resource_group_name
  location            = local.location

  open_external_ports   = local.open_external_ports
  open_external_sources = local.open_external_sources
  peer_vnet_rg          = local.peer_vnet_rg
  peer_vnet_name        = local.peer_vnet_name
}

resource "azurerm_resource_group" "windows" {
  name     = local.windows_rg
  location = local.location
}

resource "azurerm_public_ip" "windows_vm_public_ip" {
  name                = "windows_vm_nic-publicip"
  location            = local.location
  resource_group_name = local.windows_rg
  allocation_method   = "Static"
  depends_on          = [
    azurerm_resource_group.windows,
  ]
}

resource "azurerm_network_interface" "windows_vm_nic" {
  name                = "windows_vm_nic"
  location            = azurerm_resource_group.windows.location
  resource_group_name = azurerm_resource_group.windows.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.network.jumpbox_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows_vm_public_ip.id
  }
  
  depends_on = [
    module.network,
  ]
}

resource "azurerm_windows_virtual_machine" "windows_vm" {
  name                = "windows-dc-vm"
  resource_group_name = azurerm_resource_group.windows.name
  location            = azurerm_resource_group.windows.location
  size                = "Standard_F2"
  admin_username      = local.vm_admin_username
  admin_password      = local.vm_admin_password
  custom_data           = base64gzip(local.powershell_script)
  network_interface_ids = [
    azurerm_network_interface.windows_vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "windows_vm_cse" {
  name                 = "vmsetup"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
       "commandToExecute": "${local.windows_custom_script} > %SYSTEMDRIVE%\\AzureData\\CustomDataSetupScript.log 2>&1"
    }
SETTINGS
}

output "windows_vm_ip" {
  value = azurerm_public_ip.windows_vm_public_ip.ip_address
}