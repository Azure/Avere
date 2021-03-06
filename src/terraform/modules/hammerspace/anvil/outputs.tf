output "admin_username" {
  value = var.admin_username
}

output "web_ui_username" {
  value = "admin"
}

// put both passwords for ha mode
output "web_ui_password" {
  value = azurerm_linux_virtual_machine.anvilvm == null || length(azurerm_linux_virtual_machine.anvilvm) == 0 ? [] : local.is_high_availability ? [azurerm_linux_virtual_machine.anvilvm[0].virtual_machine_id, azurerm_linux_virtual_machine.anvilvm[1].virtual_machine_id] : [azurerm_linux_virtual_machine.anvilvm[0].virtual_machine_id]
}

output "arm_virtual_machine_ids" {
  value = azurerm_linux_virtual_machine.anvilvm == null || length(azurerm_linux_virtual_machine.anvilvm) == 0 ? [] : local.is_high_availability ? [azurerm_linux_virtual_machine.anvilvm[0].id, azurerm_linux_virtual_machine.anvilvm[1].id] : [azurerm_linux_virtual_machine.anvilvm[0].id]
}

output "deployment_name" {
  value = var.unique_name
}

output "anvil_data_cluster_ip" {
  value = azurerm_linux_virtual_machine.anvilvm == null || length(azurerm_linux_virtual_machine.anvilvm) == 0 ? "" : local.is_high_availability ? azurerm_lb.anvilloadbalancer[0].frontend_ip_configuration[0].private_ip_address : azurerm_network_interface.anvildata[0].ip_configuration[0].private_ip_address
}

output "anvil_data_cluster_data_ips" {
  value = azurerm_linux_virtual_machine.anvilvm == null || length(azurerm_linux_virtual_machine.anvilvm) == 0 ? [] : local.is_high_availability ? [azurerm_network_interface.anvildata[0].ip_configuration[0].private_ip_address, azurerm_network_interface.anvildata[1].ip_configuration[0].private_ip_address] : [azurerm_network_interface.anvildata[0].ip_configuration[0].private_ip_address]
}

output "anvil_domain" {
  value = local.domain
}

output "anvil_host_names" {
  value = local.anvil_host_names
}
