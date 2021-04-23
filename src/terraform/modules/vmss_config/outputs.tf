output "bootstrap_script_path" {
  description = "The path of the mount script on the NFS share."
  value       = "/${local.bootstrap_dir}/bootstrap.sh"
}
