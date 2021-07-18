# CacheWarmer Submit Multiple Jobs Module

This module submits multiple jobs and allows for blocking on the warming.

Here is an example:

```terraform
module "cachewarmer_submitmultipejobs" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_submitmultiplejobs"

  // authentication with controller
  node_address = local.controller_address
  admin_username = local.controller_username
  admin_password = local.vm_admin_password
  ssh_key_data = local.vm_ssh_key_data
  
  // the job path
  storage_account = "REPLACE"
  storage_key = "REPLACE"
  queue_name_prefix = "isilonfiler1"

  // the path to warm
  warm_mount_addresses = join(",", tolist([
    "10.0.1.11",
    "10.0.1.12",
    "10.0.1.13",
  ]))
  warm_paths = {
    "/data" : ["/island/animation", "/island/json","/island/obj","/island/pbrt","/island/ref","/island/scripts","/island/textures"],
  }
}
```