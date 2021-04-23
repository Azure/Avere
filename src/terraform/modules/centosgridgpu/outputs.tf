output "address" {
  value = azurerm_network_interface.vm.ip_configuration[0].private_ip_address
}

output "username" {
  value = var.admin_username
}

output "module_depends_on_id" {
  description = "the id(s) to force others to wait"
  value       = azurerm_virtual_machine_extension.cse.id
}
