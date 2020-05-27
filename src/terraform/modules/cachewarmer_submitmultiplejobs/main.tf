locals {
  mount_dir = "/b"
  block_flag = " -blockUntilWarm "
  no_block_flag = ""
  warm_paths_array = [for i, z in var.warm_paths: setproduct([i], z)][0]
}

resource "null_resource" "cachewarmer_submitmultiplejobs" {
  count = length(local.warm_paths_array)

  connection {
      type  = "ssh"
      host  = var.node_address
      user  = var.admin_username
      password = var.ssh_key_data != null && var.ssh_key_data != "" ? "" : var.admin_password
      private_key = var.ssh_key_data != null && var.ssh_key_data != "" ? file("~/.ssh/id_rsa") : null
  }
  
  provisioner "remote-exec" {
    inline = [
      "set -x",
      join("", ["sudo /usr/local/bin/cachewarmer-jobsubmitter -jobBasePath ", var.job_base_path, " -jobExportPath ", var.job_export_path, " -jobMountAddress ", var.jobMount_address, " -warmTargetExportPath ", local.warm_paths_array[count.index][0], " -warmTargetMountAddresses ", var.warm_mount_addresses, " -warmTargetPath ", local.warm_paths_array[count.index][1], " ", var.block_until_warm && count.index == 0 ? local.block_flag : local.no_block_flag]),
    ]
  }

  depends_on = [var.module_depends_on]
}

