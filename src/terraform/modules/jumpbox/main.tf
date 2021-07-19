locals {
  # send the script file to custom data, adding env vars
  script_file_b64 = base64gzip(replace(file("${path.module}/install.sh"), "\r", ""))
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { installcmd = local.script_file_b64, ssh_port = var.ssh_port })
}

data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group
}

data "azurerm_subscription" "primary" {}

data "azurerm_resource_group" "vm" {
  name = var.resource_group_name
}

resource "azurerm_public_ip" "vm" {
  name                = "${var.unique_name}-publicip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.vm.name
  allocation_method   = "Static"

  count = var.add_public_ip ? 1 : 0
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.unique_name}-nic"
  resource_group_name = data.azurerm_resource_group.vm.name
  location            = var.location

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = var.static_ip_address == null || var.static_ip_address == "" ? "Dynamic" : "Static"
    private_ip_address            = var.static_ip_address == null || var.static_ip_address == "" ? null : var.static_ip_address
    public_ip_address_id          = var.add_public_ip ? azurerm_public_ip.vm[0].id : ""
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.unique_name}-vm"
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.vm.name
  network_interface_ids = [azurerm_network_interface.vm.id]
  computer_name         = var.unique_name
  custom_data           = base64encode(local.cloud_init_file)
  size                  = var.vm_size

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name                 = "${var.unique_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.7"
    version   = "latest"
  }

  admin_username                  = var.admin_username
  admin_password                  = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? var.admin_password : null
  disable_password_authentication = (var.ssh_key_data == null || var.ssh_key_data == "") && var.admin_password != null && var.admin_password != "" ? false : true
  dynamic "admin_ssh_key" {
    for_each = var.ssh_key_data == null || var.ssh_key_data == "" ? [] : [var.ssh_key_data]
    content {
      username   = var.admin_username
      public_key = var.ssh_key_data
    }
  }
}

resource "azurerm_virtual_machine_extension" "cse" {
  name                 = "${var.unique_name}-cse"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": " ADMIN_USER_NAME=${var.admin_username} BUILD_VFXT_PROVIDER=${var.build_vfxt_terraform_provider} /bin/bash /opt/install.sh"
    }
SETTINGS
}

locals {
  vm_contributor_rgs = distinct(concat(
    [
      var.resource_group_name,
      var.virtual_network_resource_group,
    ],
  var.alternative_resource_groups))
}

resource "azurerm_role_assignment" "create_cluster_role" {
  count                            = var.add_role_assignments ? length(local.vm_contributor_rgs) : 0
  scope                            = "${data.azurerm_subscription.primary.id}/resourceGroups/${local.vm_contributor_rgs[count.index]}"
  role_definition_name             = "Virtual Machine Contributor"
  principal_id                     = azurerm_linux_virtual_machine.vm.identity[0].principal_id
  skip_service_principal_aad_check = true
}

