output "primary_ip" {
  value = azurerm_network_interface.nfsfiler.ip_configuration[0].private_ip_address
}

output "admin_username" {
  value = var.admin_username
}

output "core_filer_export" {
  value = var.nfs_export_path
}

output "nfs_mount" {
  value = "${azurerm_network_interface.nfsfiler.ip_configuration[0].private_ip_address}:${var.nfs_export_path}"
}

output "ssh_string" {
  value = "ssh ${var.admin_username}@${azurerm_network_interface.nfsfiler.ip_configuration[0].private_ip_address}"
}
