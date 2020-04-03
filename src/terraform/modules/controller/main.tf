data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

data "azurerm_subscription" "primary" {}

locals {
  # send the script file to custom data, adding env vars
  script_file_b64 = base64gzip(replace(file("${path.module}/averecmd.txt"),"\r",""))
  msazure_patch1_file_b64 = base64gzip(replace(file("${path.module}/msazure.py.patch1"),"\r",""))
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { averecmd = local.script_file_b64, msazure_patch1 = local.msazure_patch1_file_b64 })
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

  count = var.create_resource_group ? 1 : 0
}

data "azurerm_resource_group" "vm" {
  name = var.resource_group_name

  count = var.create_resource_group ? 0 : 1
}

resource "azurerm_public_ip" "vm" {
    name                         = "${var.unique_name}-publicip"
    location                     = var.create_resource_group ? azurerm_resource_group.vm[0].location : data.azurerm_resource_group.vm[0].location
    resource_group_name          = var.create_resource_group ? azurerm_resource_group.vm[0].name : data.azurerm_resource_group.vm[0].name
    allocation_method            = "Static"

    count = var.add_public_ip ? 1 : 0
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.unique_name}-nic"
  resource_group_name = var.create_resource_group ? azurerm_resource_group.vm[0].name : data.azurerm_resource_group.vm[0].name
  location            = var.create_resource_group ? azurerm_resource_group.vm[0].location : data.azurerm_resource_group.vm[0].location

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.add_public_ip ? azurerm_public_ip.vm[0].id : ""
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name = "${var.unique_name}-vm"
  location = var.create_resource_group ? azurerm_resource_group.vm[0].location : data.azurerm_resource_group.vm[0].location
  resource_group_name = var.create_resource_group ? azurerm_resource_group.vm[0].name : data.azurerm_resource_group.vm[0].name
  network_interface_ids = [azurerm_network_interface.vm.id]
  computer_name  = var.unique_name
  custom_data = base64encode(local.cloud_init_file)
  size = var.vm_size
  
  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name              = "${var.unique_name}-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
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

  admin_username = var.admin_username
  admin_password = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? var.admin_password : null
  disable_password_authentication = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? false : true
  dynamic "admin_ssh_key" {
      for_each = var.ssh_key_data == null || var.ssh_key_data == "" ? [] : [var.ssh_key_data]
      content {
          username   = var.admin_username
          public_key = var.ssh_key_data
      }
  }
}

resource "azurerm_role_assignment" "create_vfxt_cluster" {
  scope              = data.azurerm_subscription.primary.id
  role_definition_name = local.avere_create_cluster_role
  principal_id       = azurerm_linux_virtual_machine.vm.identity[0].principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "user_access_admin" {
  scope              = data.azurerm_subscription.primary.id
  role_definition_name = local.user_access_administrator_role
  principal_id       = azurerm_linux_virtual_machine.vm.identity[0].principal_id
  skip_service_principal_aad_check = true
}