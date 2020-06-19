// customize the VMSS by editing the following local variables
locals {
    vmss_resource_group_name = "houdini_vmss_rg"
    unique_name = "unique"
    source_image_id = ""
    vm_count = 2
    vmss_size = "Standard_D4s_v3"
    // Specify to use 'Regular' or 'Spot'
    vmss_priority = "Regular"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "ReplacePassword$"

    // replace below variables with the infrastructure variables from 1.base_infrastructure
    location = ""
    vnet_render_clients1_subnet_id = ""
  
    // replace below variables with the cache variables from 2.cache
    mount_addresses = []
    mount_path = ""

    // advanced scenarios: the below variables rarely need to change  
    single_mount_address = tolist(local.mount_addresses)[0]
    target_path = "c:\\\\cloudcache"

    // the following are the arguments to be passed to the custom script
    windows_custom_script_arguments = "$arguments = '-UserName ${local.vm_admin_username} -MountIP ${local.single_mount_address} -MountPath ${local.mount_path} -TargetPath ${local.target_path} '  ; "

    // load the powershell file, you can substitute kv pairs as you need them, but 
    // use arguments where possible
    powershell_script = file("${path.module}/setupMachine.ps1")
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

resource "azurerm_resource_group" "vmss" {
  name     = local.vmss_resource_group_name
  location = local.location
}

locals {
  // the following powershell code will unzip and de-base64 the custom data payload enabling it
  // to be executed as a powershell script
  windows_custom_script_suffix = " $inputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomData.bin' ; $outputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomDataSetupScript.ps1' ; $inputStream = New-Object System.IO.FileStream $inputFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read) ; $sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)) ; $sr.ReadToEnd() | Out-File($outputFile) ; Invoke-Expression('{0} {1}' -f $outputFile, $arguments) ; "

  windows_custom_script = "powershell.exe -ExecutionPolicy Unrestricted -command \\\"${local.windows_custom_script_arguments} ${local.windows_custom_script_suffix}\\\""
}

resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = local.unique_name
  resource_group_name = azurerm_resource_group.vmss.name
  location            = azurerm_resource_group.vmss.location
  upgrade_policy_mode = "Manual"
  priority            = local.vmss_priority
  eviction_policy     = local.vmss_priority == "Spot" ? "Delete" : null
  // avoid overprovision as it can create race conditions with render managers
  overprovision       = false

  sku {
    name = local.vmss_size
    tier = "Standard"
    capacity = local.vm_count
  }
    
  os_profile {
    computer_name_prefix = local.unique_name
    admin_username       = local.vm_admin_username
    admin_password       = local.vm_admin_password
    custom_data          = base64gzip(local.powershell_script)
  }

  storage_profile_image_reference {
    id = local.source_image_id
  }

  storage_profile_os_disk  {
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option     = "FromImage"
  }

  network_profile {
    name    = "vminic-${local.unique_name}"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = local.vnet_render_clients1_subnet_id
    }
  }

  extension {
    name                 = "${local.unique_name}-cse"
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.10"

    settings = <<SETTINGS
    {
        "commandToExecute": "${local.windows_custom_script} > %SYSTEMDRIVE%\\AzureData\\CustomDataSetupScript.log 2>&1"
    }
SETTINGS
  }

}

output "vmss_id" {
  value = azurerm_virtual_machine_scale_set.vmss.id
}

output "vmss_resource_group" {
  value = azurerm_resource_group.vmss.name
}

output "vmss_name" {
  value = azurerm_virtual_machine_scale_set.vmss.name
}

output "vmss_addresses_command" {
    // local-exec doesn't return output, and the only way to 
    // try to get the output is follow advice from https://stackoverflow.com/questions/49136537/obtain-ip-of-internal-load-balancer-in-app-service-environment/49436100#49436100
    // in the meantime just provide the az cli command to
    // the customer
    value = "az vmss nic list -g ${azurerm_resource_group.vmss.name} --vmss-name ${azurerm_virtual_machine_scale_set.vmss.name} --query \"[].ipConfigurations[].privateIpAddress\""
}