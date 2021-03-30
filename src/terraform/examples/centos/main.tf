// customize the Secured VM by adjusting the following local variables
locals {
    // the region of the deployment
    location = "eastus"
    vm_admin_username = "azureuser"
    // use either SSH Key data or admin password, if ssh_key_data is specified
    // then admin_password is ignored
    vm_admin_password = "PASSWORD"
    // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
    // populated where you are running terraform
    vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

    resource_group_name = "centosresource_group"
    vm_size = "Standard_D2s_v3"

    // the below is the resource group and name of the previously created custom image
    image_resource_group = "image_resource_group"
    image_name = "image_name" 

    // network details
    virtual_network_resource_group = "network_resource_group"
    virtual_network_name = "rendervnet"
    virtual_network_subnet_name = "render_clients2"

    // update search domain with space separated list of search domains, leave blank to not set
    search_domain = ""

    // this value for OS Disk resize must be between 20GB and 1023GB,
    // after this you will need to repartition the disk
    os_disk_size_gb = 32 

    script_file_b64 = base64gzip(replace(file("${path.module}/installnfs.sh"),"\r",""))
    cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { install_script = local.script_file_b64, search_domain = local.search_domain})
}

provider "azurerm" {
    version = "~>2.12.0"
    features {}
}

data "azurerm_subnet" "vnet" {
  name                 = local.virtual_network_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.virtual_network_resource_group
}

data "azurerm_image" "custom_image" {
    name = local.image_name
    resource_group_name = local.image_resource_group
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_network_interface" "main" {
  name                = "nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                  = "vm"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  network_interface_ids = [azurerm_network_interface.main.id]
  computer_name         = "vm"
  size                  = local.vm_size
  custom_data           = base64encode(local.cloud_init_file)
  source_image_id       = data.azurerm_image.custom_image.id
    
  // by default the OS has encryption at rest
  os_disk {
    name = "osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = local.os_disk_size_gb
  }

  admin_username = local.vm_admin_username
  admin_password = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? local.vm_admin_password : null
  disable_password_authentication = (local.vm_ssh_key_data == null || local.vm_ssh_key_data == "") && local.vm_admin_password != null && local.vm_admin_password != "" ? false : true
  dynamic "admin_ssh_key" {
      for_each = local.vm_ssh_key_data == null || local.vm_ssh_key_data == "" ? [] : [local.vm_ssh_key_data]
      content {
          username   = local.vm_admin_username
          public_key = local.vm_ssh_key_data
      }
  }
}

resource "azurerm_virtual_machine_extension" "cse" {
  name = "vm-cse"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  # replace the below with a script you would like to run
  # A custom script extension (cse) is useful over cloud-init
  # for 2 reasons:
  #   1. safe to deliver secrets
  #   2. provides success or fail signal back to deployment
  settings = <<SETTINGS
    {
        "commandToExecute": " mkdir -p /opt/cse"
    }
SETTINGS
}

output "username" {
  value = local.vm_admin_username
}

output "vm_address" {
  value = azurerm_network_interface.main.ip_configuration[0].private_ip_address
}

output "ssh_command" {
    value = "ssh ${local.vm_admin_username}@${azurerm_network_interface.main.ip_configuration[0].private_ip_address}"
}