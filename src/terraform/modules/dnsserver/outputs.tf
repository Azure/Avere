output "dnsserver_address" {
  value = azurerm_network_interface.vm.ip_configuration[0].private_ip_address
}

output "dnsserver_username" {
  value = var.admin_username
}
