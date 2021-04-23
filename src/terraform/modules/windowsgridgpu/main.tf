locals {
  grid_url     = var.install_pcoip ? var.grid_url : ""
  teradici_url = var.install_pcoip ? var.teradici_pcoipagent_url : ""

  # send the script file to custom data, adding env vars
  windows_custom_script_suffix = " $inputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomData.bin' ; $outputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomDataSetupScript.ps1' ; $inputStream = New-Object System.IO.FileStream $inputFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read) ; $sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)) ; $sr.ReadToEnd() | Out-File($outputFile) ; Invoke-Expression('{0} {1}' -f $outputFile, $arguments) ; "

  windows_custom_script_arguments = "$arguments = ' -ADDomain ''${var.ad_domain}'' -OUPath ''${var.ou_path}'' -DomainUser ''${var.ad_username}'' -DomainPassword ''${var.ad_password}'' -TeradiciLicenseKey ''${var.teradici_license_key}'' -GridUrl ''${local.grid_url}'' -TeradiciPcoipAgentUrl ''${local.teradici_url}'' '; "

  windows_custom_script = "powershell.exe -ExecutionPolicy Unrestricted -command \\\"${local.windows_custom_script_arguments} ${local.windows_custom_script_suffix}\\\""

  powershell_script = file("${path.module}/setupMachine.ps1")
}

data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

data "azurerm_subscription" "primary" {}

data "azurerm_resource_group" "vm" {
  name     = var.resource_group_name
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.unique_name}-nic"
  resource_group_name = data.azurerm_resource_group.vm.name
  location            = var.location

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = var.private_ip_address != null ? "Static" : "Dynamic"
    private_ip_address            = var.private_ip_address != null ? var.private_ip_address : null
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "${var.unique_name}-vm"
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.vm.name
  computer_name         = var.unique_name
  custom_data           = base64gzip(local.powershell_script)
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  size                  = var.vm_size
  network_interface_ids = [azurerm_network_interface.vm.id]
  license_type          = var.license_type
  
  os_disk {
    name                 = "${var.unique_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type
  }

  source_image_id = var.image_id != null && var.image_id != "" ? var.image_id : null

  dynamic "source_image_reference" {
    for_each = var.image_id != null && var.image_id != "" ? [] : ["windows desktop"]
    content {
      publisher = "MicrosoftWindowsDesktop"
      offer     = "Windows-10"
      sku       = "20h2-pro"
      #sku       = "20h1-entn" // uncomment for 2004
      version   = "latest"
    }
  }
}

resource "azurerm_virtual_machine_extension" "cse" {
  name                 = "${var.unique_name}-cse"
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
