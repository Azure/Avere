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
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  rdp_port        = 5555

  // network details
  network_resource_group_name = "smb_test_network_resource_group"
  render_subnet_id = "/subscriptions/2b82274c-a71a-4088-9e0b-d503825a2b2a/resourceGroups/smb_test_network_resource_group/providers/Microsoft.Network/virtualNetworks/rendervnet/subnets/render_clients1"

  # namespace_path           = "/storagevfxt"

  # Windows VM for DC set up
  windows_rg = "smb_test_windows_clients"
  // the following are the arguments to be passed to the custom script
  windows_custom_script_arguments = "$arguments = '-RdpPort ${local.rdp_port}' ; "

  // load the powershell file, you can substitute kv pairs as you need them, but 
  // use arguments where possible
  powershell_script = templatefile("setupMachine.ps1", {})

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

resource "azurerm_resource_group" "windows" {
  name     = local.windows_rg
  location = local.location
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set#example-usage
# https://github.com/hashicorp/terraform-provider-azurerm/blob/main/examples/vm-scale-set/windows/public-ip-per-instance/main.tf
resource "azurerm_public_ip_prefix" "vmsspip" {
  name                = "smb-test-pip"
  location            = azurerm_resource_group.windows.location
  resource_group_name = azurerm_resource_group.windows.name
}

resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                 = "smb-test-vmss"
  resource_group_name  = azurerm_resource_group.windows.name
  location             = azurerm_resource_group.windows.location
  sku                  = "Standard_F2s_v2"
  instances            = 3
  admin_username       = local.vm_admin_username
  admin_password       = local.vm_admin_password
  computer_name_prefix = "smb-test"
  custom_data           = base64gzip(local.powershell_script)

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  network_interface {
    name    = "example"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = local.render_subnet_id

      public_ip_address {
        name                = "first"
        public_ip_prefix_id = azurerm_public_ip_prefix.vmsspip.id
      }
    }
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"

    // Ephemeral disks is enabled
    # diff_disk_settings {
    #   option = "Local"
    # }
  }

  extension {
    name                       = "CustomScript"
    publisher                  = "Microsoft.Compute"
    type                       = "CustomScriptExtension"
    type_handler_version       = "1.10"
    auto_upgrade_minor_version = true

    settings = jsonencode({ "commandToExecute" = "${local.windows_custom_script} > %SYSTEMDRIVE%\\AzureData\\CustomDataSetupScript.log 2>&1" })
  }
}