output "controller_address" {
  value = var.deploy_controller ? (var.add_public_ip ? azurerm_public_ip.vm[0].ip_address : azurerm_network_interface.vm[0].ip_configuration[0].private_ip_address) : ""
}

output "controller_private_address" {
  value = var.deploy_controller ? azurerm_network_interface.vm[0].ip_configuration[0].private_ip_address : ""
}

output "controller_username" {
  value = var.admin_username
}
