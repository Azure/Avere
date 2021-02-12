output "admin_username" {
  value = var.admin_username
}

output "web_ui_username" {
  value = "admin"
}

output "web_ui_password" {
  value = azurerm_linux_virtual_machine.anvilvm == null || length(azurerm_linux_virtual_machine.anvilvm) == 0 ? "" : "${azurerm_linux_virtual_machine.anvilvm[0].virtual_machine_id}${local.is_high_availability ? " or " : ""}${local.is_high_availability ? azurerm_linux_virtual_machine.anvilvm[1].virtual_machine_id : ""}"
}

output "deployment_name" {
  value = var.unique_name
}

output "anvil_data_cluster_ip" {
  value = azurerm_linux_virtual_machine.anvilvm == null || length(azurerm_linux_virtual_machine.anvilvm) == 0 ? "" : local.is_high_availability ? azurerm_lb.anvilloadbalancer[0].frontend_ip_configuration[0].private_ip_address : azurerm_network_interface.anvildata[0].ip_configuration[0].private_ip_address
}

output "anvil_data_cluster_ip_mask_bits" {
  value = local.data_mask_bits
}

output "anvil_domain" {
  value = local.domain
}

