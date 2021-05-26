output "admin_username" {
  value = var.admin_username
}

output "deployment_name" {
  value = var.unique_name
}

output "dsx_ip_addresses" {
  value = [for n in azurerm_network_interface.dsxdata : n.ip_configuration[0].private_ip_address]
}
