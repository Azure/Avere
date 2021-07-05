output "vm_id" {
  value = azurerm_linux_virtual_machine.wireguard.id
}

output "public_ip_address" {
  value = azurerm_public_ip.wireguard.ip_address
}

output "private_ip_address" {
  value = azurerm_network_interface.wireguard.ip_configuration[0].private_ip_address
}
