output "job_mount_address" {
  description = "The address of the nfs filer where the warm jobs are submitted."
  value       = var.jobMount_address
}

output "job_export_path" {
  description = "The export path where the warm jobs are submitted."
  value       = var.job_export_path
}

output "job_path" {
  description = "The path of the cachewarmer worker on the NFS share."
  value       = var.job_base_path
}
