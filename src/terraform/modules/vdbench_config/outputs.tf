output "bootstrap_script_path" {
  description = "The path of the vdbench script on the NFS share."
  value       = "/${local.bootstrap_dir}/bootstrap.vdbench.sh"
}

output "module_depends_on_id" {
  description = "the id(s) to force others to wait"
  value = null_resource.install_vdbench_bootstrap.id
}