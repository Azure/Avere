locals {

  local_list_a_records         = length(var.avere_address_list) == 0 ? [] : [for i in range(length(var.avere_address_list)) : "local-data: \"${var.avere_filer_fqdn} ${var.dns_max_ttl_seconds} A ${var.avere_address_list[i]}\""]
  local_list_a_records_reverse = length(var.avere_address_list) == 0 ? [] : [for i in range(length(var.avere_address_list)) : "local-data-ptr: \"${var.avere_address_list[i]} ${var.dns_max_ttl_seconds} ${var.avere_filer_fqdn}\""]

  # alternate fqdn
  local_alternate_list_a_records = length(var.avere_address_list) == 0 ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(length(var.avere_address_list)) :
      "local-data: \"${var.avere_filer_alternate_fqdn[i]} ${var.dns_max_ttl_seconds} A ${var.avere_address_list[j]}\""
    ]
  ])
  # reverse records
  local_alternate_list_a_records_reverse = length(var.avere_address_list) == 0 ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(length(var.avere_address_list)) :
      "local-data-ptr: \"${var.avere_address_list[j]} ${var.dns_max_ttl_seconds} ${var.avere_filer_alternate_fqdn[i]}\""
    ]
  ])

  # create the A record lines for the first Avere
  last_octet  = var.avere_first_ip_addr == "" ? "" : split(".", var.avere_first_ip_addr)[3]
  addr_prefix = var.avere_first_ip_addr == "" ? "" : trimsuffix(var.avere_first_ip_addr, ".${local.last_octet}")
  # technique from article: https://forum.netgate.com/topic/120486/round-robin-for-dns-forwarder-network-address/3
  local_a_records         = var.avere_first_ip_addr == "" ? [] : [for i in range(var.avere_ip_addr_count) : "local-data: \"${var.avere_filer_fqdn} ${var.dns_max_ttl_seconds} A ${local.addr_prefix}.${local.last_octet + i}\""]
  local_a_records_reverse = var.avere_first_ip_addr == "" ? [] : [for i in range(var.avere_ip_addr_count) : "local-data-ptr: \"${local.addr_prefix}.${local.last_octet + i} ${var.dns_max_ttl_seconds} ${var.avere_filer_fqdn}\""]

  # alternate fqdn
  local_alternate_a_records = var.avere_first_ip_addr == "" ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(var.avere_ip_addr_count) :
      "local-data: \"${var.avere_filer_alternate_fqdn[i]} ${var.dns_max_ttl_seconds} A ${local.addr_prefix}.${local.last_octet + j}\""
    ]
  ])
  # reverse records
  local_alternate_a_records_reverse = var.avere_first_ip_addr == "" ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(var.avere_ip_addr_count) :
      "local-data-ptr: \"${local.addr_prefix}.${local.last_octet + j} ${var.dns_max_ttl_seconds} ${var.avere_filer_alternate_fqdn[i]}\""
    ]
  ])

  # create the A record lines for the second Avere
  last_octet2  = var.avere_first_ip_addr2 == "" ? "" : split(".", var.avere_first_ip_addr2)[3]
  addr_prefix2 = var.avere_first_ip_addr2 == "" ? "" : trimsuffix(var.avere_first_ip_addr2, ".${local.last_octet2}")

  local_a_records2         = var.avere_first_ip_addr2 == "" ? [] : [for i in range(var.avere_ip_addr_count2) : "local-data: \"${var.avere_filer_fqdn} ${var.dns_max_ttl_seconds} A ${local.addr_prefix2}.${local.last_octet2 + i}\""]
  local_a_records_reverse2 = var.avere_first_ip_addr2 == "" ? [] : [for i in range(var.avere_ip_addr_count2) : "local-data-ptr: \"${local.addr_prefix2}.${local.last_octet2 + i} ${var.dns_max_ttl_seconds} ${var.avere_filer_fqdn}\""]

  # alternate fqdn
  local_alternate_a_records2 = var.avere_first_ip_addr2 == "" ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(var.avere_ip_addr_count2) :
      "local-data: \"${var.avere_filer_alternate_fqdn[i]} ${var.dns_max_ttl_seconds} A ${local.addr_prefix2}.${local.last_octet2 + j}\""
    ]
  ])
  # reverse records
  local_alternate_a_records_reverse2 = var.avere_first_ip_addr2 == "" ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(var.avere_ip_addr_count2) :
      "local-data-ptr: \"${local.addr_prefix2}.${local.last_octet2 + j} ${var.dns_max_ttl_seconds} ${var.avere_filer_alternate_fqdn[i]}\""
    ]
  ])

  # create the A record lines for the third Avere
  last_octet3  = var.avere_first_ip_addr3 == "" ? "" : split(".", var.avere_first_ip_addr3)[3]
  addr_prefix3 = var.avere_first_ip_addr3 == "" ? "" : trimsuffix(var.avere_first_ip_addr3, ".${local.last_octet3}")

  local_a_records3         = var.avere_first_ip_addr3 == "" ? [] : [for i in range(var.avere_ip_addr_count3) : "local-data: \"${var.avere_filer_fqdn} ${var.dns_max_ttl_seconds} A ${local.addr_prefix3}.${local.last_octet3 + i}\""]
  local_a_records_reverse3 = var.avere_first_ip_addr3 == "" ? [] : [for i in range(var.avere_ip_addr_count3) : "local-data-ptr: \"${local.addr_prefix3}.${local.last_octet3 + i} ${var.dns_max_ttl_seconds} ${var.avere_filer_fqdn}\""]

  # alternate fqdn
  local_alternate_a_records3 = var.avere_first_ip_addr3 == "" ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(var.avere_ip_addr_count3) :
      "local-data: \"${var.avere_filer_alternate_fqdn[i]} ${var.dns_max_ttl_seconds} A ${local.addr_prefix3}.${local.last_octet3 + j}\""
    ]
  ])
  # reverse records
  local_alternate_a_records_reverse3 = var.avere_first_ip_addr3 == "" ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(var.avere_ip_addr_count3) :
      "local-data-ptr: \"${local.addr_prefix3}.${local.last_octet3 + j} ${var.dns_max_ttl_seconds} ${var.avere_filer_alternate_fqdn[i]}\""
    ]
  ])

  # create the A record lines for the fourth Avere
  last_octet4  = var.avere_first_ip_addr4 == "" ? "" : split(".", var.avere_first_ip_addr4)[3]
  addr_prefix4 = var.avere_first_ip_addr4 == "" ? "" : trimsuffix(var.avere_first_ip_addr4, ".${local.last_octet4}")

  local_a_records4         = var.avere_first_ip_addr4 == "" ? [] : [for i in range(var.avere_ip_addr_count4) : "local-data: \"${var.avere_filer_fqdn} ${var.dns_max_ttl_seconds} A ${local.addr_prefix4}.${local.last_octet4 + i}\""]
  local_a_records_reverse4 = var.avere_first_ip_addr4 == "" ? [] : [for i in range(var.avere_ip_addr_count4) : "local-data-ptr: \"${local.addr_prefix4}.${local.last_octet4 + i} ${var.dns_max_ttl_seconds} ${var.avere_filer_fqdn}\""]

  # alternate fqdn
  local_alternate_a_records4 = var.avere_first_ip_addr4 == "" ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(var.avere_ip_addr_count4) :
      "local-data: \"${var.avere_filer_alternate_fqdn[i]} ${var.dns_max_ttl_seconds} A ${local.addr_prefix4}.${local.last_octet4 + j}\""
    ]
  ])
  # reverse records
  local_alternate_a_records_reverse4 = var.avere_first_ip_addr4 == "" ? [] : flatten([
    for i in range(length(var.avere_filer_alternate_fqdn)) : [
      for j in range(var.avere_ip_addr_count4) :
      "local-data-ptr: \"${local.addr_prefix4}.${local.last_octet4 + j} ${var.dns_max_ttl_seconds} ${var.avere_filer_alternate_fqdn[i]}\""
    ]
  ])

  # join everything into the same string
  all_a_records         = concat(local.local_list_a_records, local.local_list_a_records_reverse, local.local_alternate_list_a_records, local.local_alternate_list_a_records_reverse, local.local_a_records, local.local_a_records_reverse, local.local_alternate_a_records, local.local_alternate_a_records_reverse, local.local_a_records2, local.local_a_records_reverse2, local.local_alternate_a_records2, local.local_alternate_a_records_reverse2, local.local_a_records3, local.local_a_records_reverse3, local.local_alternate_a_records3, local.local_alternate_a_records_reverse3, local.local_a_records4, local.local_a_records_reverse4, local.local_alternate_a_records4, local.local_alternate_a_records_reverse4)
  local_zone_record_str = "local-zone: \"${var.avere_filer_fqdn}\" transparent"
  local_a_records_str   = join("\n  ", local.all_a_records)

  # create the dns forward lines  
  dns_servers      = var.dns_server == null || var.dns_server == "" ? [] : split(" ", var.dns_server)
  forward_lines    = [for s in local.dns_servers : "forward-addr: ${s}" if trimspace(s) != ""]
  foward_lines_str = join("\n  ", local.forward_lines)

  excluded_subnets     = [for s in var.excluded_subnet_cidrs : "access-control-view: ${s} excludedsubnetview" if trimspace(s) != ""]
  excluded_subnets_str = join("\n  ", local.excluded_subnets)

  # send the script file to custom data, adding env vars
  script_file_b64       = base64gzip(replace(file("${path.module}/install.sh"), "\r", ""))
  unbound_conf_file_b64 = base64gzip(replace(templatefile("${path.module}/unbound.conf", { max_ttl = var.dns_max_ttl_seconds, excluded_subnets = local.excluded_subnets_str, local_zone_line = local.local_zone_record_str, arecord_lines = local.local_a_records_str, forward_addr_lines = local.foward_lines_str }), "\r", ""))
  cloud_init_file       = templatefile("${path.module}/cloud-init.tpl", { installcmd = local.script_file_b64, unboundconf = local.unbound_conf_file_b64, ssh_port = var.ssh_port })

  proxy_env = (var.proxy == null || var.proxy == "") ? "" : "http_proxy=${var.proxy} https_proxy=${var.proxy} no_proxy=169.254.169.254"
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

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.unique_name}-vm"
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.vm.name
  network_interface_ids = [azurerm_network_interface.vm.id]
  computer_name         = var.unique_name
  custom_data           = base64encode(local.cloud_init_file)
  size                  = var.vm_size

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
        "commandToExecute": " ${local.proxy_env} /bin/bash /opt/install.sh"
    }
SETTINGS
}
