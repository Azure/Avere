data "azurerm_subnet" "vnet" {
  name                 = var.virtual_network_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group

  depends_on = [var.module_depends_on]
}

data "azurerm_subscription" "primary" {}

locals {
  # send the script file to custom data, adding env vars
  script_file_b64 = base64gzip(replace(file("${path.module}/averecmd.txt"),"\r",""))
  msazure_patch1_file_b64 = base64gzip(replace(file("${path.module}/msazure.py.patch1"),"\r",""))
  msazure_patchidentity_file_b64 = base64gzip(replace(file("${path.module}/msazure.py.patchidentity"),"\r",""))
  vfxt_patchidentity_file_b64 = base64gzip(replace(file("${path.module}/vfxt.py.patchidentity"),"\r",""))
  cloud_init_file = templatefile("${path.module}/cloud-init.tpl", { averecmd = local.script_file_b64, msazure_patch1 = local.msazure_patch1_file_b64, msazure_patchidentity = local.msazure_patchidentity_file_b64, vfxt_patchidentity = local.vfxt_patchidentity_file_b64, ssh_port = var.ssh_port })
  # the roles assigned to the controller managed identity principal
  # the contributor role is required to create Avere clusters
  avere_create_cluster_role = "Avere Contributor"
  # the user access administrator is required to assign roles.
  # the authorization team asked us to split this from Avere Contributor
  user_access_administrator_role = "User Access Administrator"
  # needed for creating various compute resources
  create_compute_role = "Virtual Machine Contributor"
}

resource "azurerm_resource_group" "vm" {
  name     = var.resource_group_name
  location = var.location

  count = var.deploy_controller && var.create_resource_group ? 1 : 0

  depends_on = [var.module_depends_on]
}

data "azurerm_resource_group" "vm" {
  name = var.resource_group_name

  count = var.create_resource_group ? 0 : 1

  depends_on = [var.module_depends_on]
}

resource "azurerm_public_ip" "vm" {
    name                         = "${var.unique_name}-publicip"
    location                     = var.location
    resource_group_name          = var.create_resource_group ? azurerm_resource_group.vm[0].name : data.azurerm_resource_group.vm[0].name
    allocation_method            = "Static"

    count = var.deploy_controller && var.add_public_ip ? 1 : 0

    depends_on = [var.module_depends_on]
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.unique_name}-nic"
  resource_group_name = var.create_resource_group ? azurerm_resource_group.vm[0].name : data.azurerm_resource_group.vm[0].name
  location            = var.location

  ip_configuration {
    name                          = "${var.unique_name}-ipconfig"
    subnet_id                     = data.azurerm_subnet.vnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.add_public_ip ? azurerm_public_ip.vm[0].id : ""
  }

  count = var.deploy_controller ? 1 : 0

  depends_on = [var.module_depends_on]
}

resource "azurerm_linux_virtual_machine" "vm" {
  name = "${var.unique_name}-vm"
  location = var.location
  resource_group_name = var.create_resource_group ? azurerm_resource_group.vm[0].name : data.azurerm_resource_group.vm[0].name
  network_interface_ids = [azurerm_network_interface.vm[0].id]
  computer_name  = var.unique_name
  custom_data = var.apply_patch ? base64encode(local.cloud_init_file) : null
  size = var.vm_size
  source_image_id = var.image_id
  
  identity {
    type = var.user_assigned_managed_identity_id == null ? "SystemAssigned" : "UserAssigned"
    identity_ids = var.user_assigned_managed_identity_id == null ? [] : [var.user_assigned_managed_identity_id]
  }

  os_disk {
    name              = "${var.unique_name}-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  dynamic "source_image_reference" {
    for_each = var.image_id == null ? ["microsoft-avere"] : []
    content {
      publisher = "microsoft-avere"
      offer     = "vfxt"
      sku       = "avere-vfxt-controller"
      version   = "1.0.12"
    }
  }

  dynamic "plan" {
    for_each = var.image_id == null ? ["microsoft-avere"] : []
    content {
      name = "avere-vfxt-controller"
      publisher = "microsoft-avere"
      product = "vfxt"
    }
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

  count = var.deploy_controller ? 1 : 0
}

// assign roles per the the following article: https://github.com/Azure/Avere/tree/main/src/vfxt#managed-identity-and-roles
// also allow other roles for storage accounts in other rgs or custom image ids in other rgs
locals {
  avere_contributor_rgs = var.user_assigned_managed_identity_id != null ? [] : distinct(concat(
    [
      var.resource_group_name,
      var.virtual_network_resource_group,
    ],
    var.alternative_resource_groups))
  
  user_access_rgs = var.user_assigned_managed_identity_id != null ? [] : distinct(
    [
      var.resource_group_name,
      var.virtual_network_resource_group,
    ]
  )

  create_compute_rgs = var.user_assigned_managed_identity_id != null ? [] : [var.resource_group_name]
}

resource "azurerm_role_assignment" "avere_create_cluster_role" {
  count                            = var.deploy_controller ? length(local.avere_contributor_rgs) : 0
  scope                            = "${data.azurerm_subscription.primary.id}/resourceGroups/${local.avere_contributor_rgs[count.index]}"
  role_definition_name             = local.avere_create_cluster_role
  principal_id                     = azurerm_linux_virtual_machine.vm[0].identity[0].principal_id
  skip_service_principal_aad_check = true

  depends_on = [azurerm_linux_virtual_machine.vm[0]]
}

resource "azurerm_role_assignment" "user_access_administrator_role" {
  count                            = var.deploy_controller ? length(local.user_access_rgs) : 0
  scope                            = "${data.azurerm_subscription.primary.id}/resourceGroups/${local.user_access_rgs[count.index]}"
  role_definition_name             = local.user_access_administrator_role
  principal_id                     = azurerm_linux_virtual_machine.vm[0].identity[0].principal_id
  skip_service_principal_aad_check = true

  depends_on = [azurerm_role_assignment.avere_create_cluster_role]
}

// ensure controller rg is a VM contributor to enable cache warming
resource "azurerm_role_assignment" "create_compute" {
  count                            = var.deploy_controller ? length(local.create_compute_rgs) : 0
  scope                            = "${data.azurerm_subscription.primary.id}/resourceGroups/${local.create_compute_rgs[count.index]}"
  role_definition_name             = local.create_compute_role
  principal_id                     = azurerm_linux_virtual_machine.vm[0].identity[0].principal_id
  skip_service_principal_aad_check = true

  depends_on = [azurerm_role_assignment.user_access_administrator_role]
}


