output "primary_ip" {
  value = var.deploy_vm ? azurerm_network_interface.nfsfiler[0].ip_configuration[0].private_ip_address : ""
}

output "admin_username" {
  value = var.admin_username
}

output "core_filer_export" {
  value = var.nfs_export_path
}

output "nfs_mount" {
  value = var.deploy_vm ? "${azurerm_network_interface.nfsfiler[0].ip_configuration[0].private_ip_address}:${var.nfs_export_path}" : ""
}

output "ssh_string" {
  value = var.deploy_vm ? "ssh ${var.admin_username}@${azurerm_network_interface.nfsfiler[0].ip_configuration[0].private_ip_address}" : ""
}
