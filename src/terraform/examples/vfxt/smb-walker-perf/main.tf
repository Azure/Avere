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
  vm_ssh_key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+lj5pn0geF6kyf1vxKfHLy/MlFOtdlhyrqdwQkw+JLhzbu2FXY/1gHpfk2Sag+1f6+yLzPww1E3Zxl46y9F/JVYyX2ZuSMmIJ+Zjy2oi8bIPIwOM3W/rt82Pcya5BAzI+HtswMR8IYclLb7mWxuiv4lyY7vsIF3OQbSAdcJ4nmFW409LEBNtKMdSKHZ3XukTqDPiIa1IjYLnzGT2qlY+aHk1ju++LCy+6u0YZYorak9HTQ47GgDraR7lTybxJYp1nRMkKAtU5ILjY/vcDD/9K0TSeeSu+eZp51O8gmfpjcQatd5kdwH2UqzpEksvlgiT4P/oTRqfjtqWW5TOivCBOqH5a2Qx44Sg9IUy+ckxLh/2h6NaIt8SlXhU+rGNBa57ywS7A2N4xTJXDPOHLtNLKYlLks+1NR1LX9zVJcuDh0lJrehQBDiOpS5HUGewNb2PzLjiWgkq44oqiljbIh3iUANxN3+DOUDz1HeV+B3fnNTI6gkL9J7R0U30KlDjMk0E= eoinbailey@RANDOM-RIHO" //"ssh-rsa AAAAB3...."
  ssh_port        = 2022
  rdp_port        = 5555

  // network details
  network_resource_group_name = "smb_test_network_resource_group"

  // storage details
  storage_resource_group_name  = "pre_pop_storage_resource_group"
  storage_account_name         = "prepopopencue"
  avere_storage_container_name = "vfxt"

  // vfxt details
  vfxt_resource_group_name = "smb_test_vfxt_resource_group"
  // if you are running a locked down network, set controller_add_public_ip to false
  controller_add_public_ip = true
  vfxt_cluster_name        = "vfxt"
  vfxt_cluster_password    = "VFXT_PASSWORD"
  vfxt_ssh_key_data        = local.vm_ssh_key_data
  namespace_path           = "/storagevfxt"

  // advanced scenario: vfxt and controller image ids, leave this null, unless not using default marketplace
  controller_image_id = null
  vfxt_image_id       = null
  // advanced scenario: in addition to storage account put the custom image resource group here
  alternative_resource_groups = [local.storage_resource_group_name]
  // advanced scenario: add external ports to work with cloud policies example [10022, 13389]
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

// the vfxt controller
module "vfxtcontroller" {
  source                      = "github.com/Azure/Avere/src/terraform/modules/controller3"
  resource_group_name         = local.vfxt_resource_group_name
  location                    = local.location
  admin_username              = local.vm_admin_username
  admin_password              = local.vm_admin_password
  ssh_key_data                = local.vm_ssh_key_data
  add_public_ip               = local.controller_add_public_ip
  image_id                    = local.controller_image_id
  alternative_resource_groups = local.alternative_resource_groups
  ssh_port                    = local.ssh_port

  // network details
  virtual_network_resource_group = local.network_resource_group_name
  virtual_network_name           = module.network.vnet_name
  virtual_network_subnet_name    = module.network.jumpbox_subnet_name

  depends_on = [
    module.network,
  ]
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
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
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


  tags = {
    environment = "Production"
  }
}


// the vfxt
resource "avere_vfxt" "vfxt" {
  controller_address        = module.vfxtcontroller.controller_address
  controller_admin_username = module.vfxtcontroller.controller_username
  // ssh key takes precedence over controller password
  controller_admin_password = local.vm_ssh_key_data != null && local.vm_ssh_key_data != "" ? "" : local.vm_admin_password
  controller_ssh_port       = local.ssh_port

  location                     = local.location
  azure_resource_group         = local.vfxt_resource_group_name
  azure_network_resource_group = local.network_resource_group_name
  azure_network_name           = module.network.vnet_name
  azure_subnet_name            = module.network.cloud_cache_subnet_name
  vfxt_cluster_name            = local.vfxt_cluster_name
  vfxt_admin_password          = local.vfxt_cluster_password
  vfxt_ssh_key_data            = local.vfxt_ssh_key_data
  vfxt_node_count              = 3
  image_id                     = local.vfxt_image_id

  # Test vFXT sku size
  node_size = "unsupported_test_SKU"
  node_cache_size = 1024

  azure_storage_filer {
    account_name            = local.storage_account_name
    container_name          = local.avere_storage_container_name
    custom_settings         = []
    junction_namespace_path = local.namespace_path
  }

  // terraform is not creating the implicit dependency on the controller module
  // otherwise during destroy, it tries to destroy the controller at the same time as vfxt cluster
  // to work around, add the explicit dependency
  depends_on = [
    module.vfxtcontroller,
  ]
}

output "controller_username" {
  value = module.vfxtcontroller.controller_username
}

output "controller_address" {
  value = module.vfxtcontroller.controller_address
}

output "ssh_command_with_avere_tunnel" {
  value = "ssh -p ${local.ssh_port} -L8443:${avere_vfxt.vfxt.vfxt_management_ip}:443 ${module.vfxtcontroller.controller_username}@${module.vfxtcontroller.controller_address}"
}

output "management_ip" {
  value = avere_vfxt.vfxt.vfxt_management_ip
}

output "mount_addresses" {
  value = tolist(avere_vfxt.vfxt.vserver_ip_addresses)
}

output "mount_namespace_path" {
  value = local.namespace_path
}

output "windows_vm_ip" {
  value = azurerm_public_ip.windows_vm_public_ip.ip_address
}