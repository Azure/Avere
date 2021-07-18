# CacheWarmer Submit Multiple Jobs Module

This module submits multiple jobs and allows for blocking on the warming.

Here is an example:

```terraform
module "cachewarmer_submitjobs" {
  source = "github.com/Azure/Avere/src/terraform/modules/cachewarmer_submitjobs"

  // authentication with controller
  jumpbox_address      = module.vfxtcontroller.controller_address
  jumpbox_username     = module.vfxtcontroller.controller_username
  jumpbox_password     = var.vm_admin_password
  jumpbox_ssh_key_data = var.vm_ssh_key_data

  // the job path
  storage_account    = "REPLACE"
  storage_account_rg = "REPLACE"
  queue_name_prefix  = "isilonfiler1"

  // the path to warm
  warm_mount_addresses = join(",", tolist([
    "10.0.1.11",
    "10.0.1.12",
    "10.0.1.13",
  ]))
  warm_paths = {
    "/data" : ["/island/animation", "/island/json","/island/obj","/island/pbrt","/island/ref","/island/scripts","/island/textures"],
  }

  inclusion_csv    = "" // example "*.jpg,*.png"
  exclusion_csv    = "" // example "*.tgz,*.tmp"
  maxFileSizeBytes = 0 // example to not scan anything over 1MB put 1048576

  block_until_warm = true
}
```