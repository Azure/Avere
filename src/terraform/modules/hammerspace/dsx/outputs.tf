output "admin_username" {
  value = var.admin_username
}

output "deployment_name" {
  value = var.unique_name
}

output "dsx_ip_addresses" {
  value = [for n in azurerm_network_interface.dsxdata : n.ip_configuration[0].private_ip_address]
}

output "module_depends_on_id" {
  description = "the id(s) to force others to wait"
  value       = var.dsx_instance_count == 0 || azurerm_virtual_machine_extension.cse == null || length(azurerm_virtual_machine_extension.cse) == 0 && var.dsx_instance_count != 0 ? data.azurerm_subnet.data_subnet.id : azurerm_virtual_machine_extension.cse[0].id
}
