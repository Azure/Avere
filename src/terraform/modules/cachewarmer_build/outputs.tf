output "bootstrap_mount_address" {
  description = "The address of the nfs filer containing the bootstrap scripts."
  value       = var.bootstrap_mount_address
}

output "bootstrap_export_path" {
  description = "The export path where the bootstrap scripts are stored."
  value       = var.bootstrap_export_path
}

output "cachewarmer_worker_bootstrap_script_path" {
  description = "The path of the cachewarmer worker on the NFS share."
  value       = local.worker_bootstrap_path
}

output "cachewarmer_manager_bootstrap_script_path" {
  description = "The path of the cachewarmer manager on the NFS share."
  value       = local.manager_bootstrap_path
}

output "module_depends_on_id" {
  description = "the id(s) to force others to wait"
  value       = null_resource.build_cachewarmer_bootstrap[0].id
}
