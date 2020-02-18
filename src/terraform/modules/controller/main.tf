provider "azurerm" {
    version = "~>1.43.0"
}

data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

data "azurerm_subscription" "primary" {}

locals {
  # send the script file to custom data, adding env vars
  script_file_b64 = base64gzip(replace(file("${path.module}/averecmd.txt"),"\r",""))
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { averecmd = local.script_file_b64 })
  # the roles assigned to the controller managed identity principal
  # the contributor role is required to create Avere clusters
  avere_create_cluster_role = "Avere Contributor"
  # the user access administrator is required to assign roles.
  # the authorization team asked us to split this from Avere Contributor
  user_access_administrator_role = "User Access Administrator"
}

resource "azurerm_resource_group" "vm" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_public_ip" "vm" {
    name                         = "${var.unique_name}-publicip"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.vm.name
    allocation_method            = "Static"

    count = var.add_public_ip ? 1 : 0
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.unique_name}-nic"
  resource_group_name = azurerm_resource_group.vm.name
  location            = azurerm_resource_group.vm.location

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.add_public_ip ? azurerm_public_ip.vm[0].id : ""
  }
}

resource "azurerm_virtual_machine" "vm" {
  name = "${var.unique_name}-vm"
  location = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  network_interface_ids = [azurerm_network_interface.vm.id]
  vm_size = var.vm_size
  delete_os_disk_on_termination = true

  identity {
    type = "SystemAssigned"
  }

  storage_os_disk {
    name              = "${var.unique_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "microsoft-avere"
    offer     = "vfxt"
    sku       = "avere-vfxt-controller"
    version   = "latest"
  }

  plan {
    name = "avere-vfxt-controller"
    publisher = "microsoft-avere"
    product = "vfxt"
  }

  dynamic "os_profile" {
    for_each = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? [var.admin_password] : [null] 
    content {
      computer_name  = var.unique_name
      admin_username = var.admin_username
      admin_password = var.admin_password
      custom_data = local.cloud_init_file
    }
  }

  // dynamic block when password is specified
  dynamic "os_profile_linux_config" {
    for_each = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? [var.admin_password] : [] 
    content {
      disable_password_authentication = false
    }
  }

  // dynamic block when SSH key is specified
  dynamic "os_profile_linux_config" {
    for_each = var.ssh_key_data == null || var.ssh_key_data == "" ? [] : [var.ssh_key_data]
    content {
      disable_password_authentication = true
      ssh_keys {
        path     = "/home/${var.admin_username}/.ssh/authorized_keys"
        key_data = var.ssh_key_data
      }
    }
  }
}

resource "azurerm_role_assignment" "create_vfxt_cluster" {
  scope              = data.azurerm_subscription.primary.id
  role_definition_name = local.avere_create_cluster_role
  principal_id       = azurerm_virtual_machine.vm.identity[0].principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "user_access_admin" {
  scope              = data.azurerm_subscription.primary.id
  role_definition_name = local.user_access_administrator_role
  principal_id       = azurerm_virtual_machine.vm.identity[0].principal_id
  skip_service_principal_aad_check = true
}