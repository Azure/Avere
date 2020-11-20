output "primary_ip" {
  value = azurerm_network_interface.cyclecloud.ip_configuration[0].private_ip_address
}

output "admin_username" {
  value = "${var.admin_username}"
}

output "ssh_string" {
  value = "ssh ${var.admin_username}@${azurerm_network_interface.cyclecloud.ip_configuration[0].private_ip_address}"
}
