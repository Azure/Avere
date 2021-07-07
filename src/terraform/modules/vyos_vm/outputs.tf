output "vm_id" {
  value = azurerm_linux_virtual_machine.vyos.id
}

output "public_ip_address" {
  value = azurerm_public_ip.vyos.ip_address
}

output "private_ip_address" {
  value = azurerm_network_interface.vyos.ip_configuration[0].private_ip_address
}
