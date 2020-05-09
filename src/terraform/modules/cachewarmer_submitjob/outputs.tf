output "module_depends_on_id" {
  description = "the id(s) to force others to wait"
  value = null_resource.cachewarmer_submitjob.id
}