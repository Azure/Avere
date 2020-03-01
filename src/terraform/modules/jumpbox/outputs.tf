output "jumpbox_address" {
  value = "${var.add_public_ip ? azurerm_public_ip.vm[0].ip_address : azurerm_network_interface.vm.ip_configuration[0].private_ip_address}"
}

output "jumpbox_username" {
  value = "${var.admin_username}"
}
