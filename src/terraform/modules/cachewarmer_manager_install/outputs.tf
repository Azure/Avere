output "module_depends_on_id" {
  description = "the id(s) to force others to wait"
  value       = null_resource.install_cachewarmer_manager[0].id
}
