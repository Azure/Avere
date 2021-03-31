locals {
  mount_dir = "/b"
  block_flag = var.block_until_warm ? " -blockUntilWarm " : ""
}

resource "null_resource" "cachewarmer_submitjob" {
  count = var.deploy_cachewarmer ? 1 : 0
  
  connection {
      type  = "ssh"
      port  = var.ssh_port
      host  = var.node_address
      user  = var.admin_username
      password = var.ssh_key_data != null && var.ssh_key_data != "" ? "" : var.admin_password
      private_key = var.ssh_key_data != null && var.ssh_key_data != "" ? file("~/.ssh/id_rsa") : null
  }
  
  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sudo /usr/local/bin/cachewarmer-jobsubmitter -storageAccountName ${var.storage_account} -storageKey ${var.storage_key} -queueNamePrefix ${var.queue_name_prefix} -warmTargetExportPath ${var.warm_target_export_path} -warmTargetMountAddresses \"${var.warm_mount_addresses}\" -warmTargetPath \"${var.warm_target_path}\" ${local.block_flag}",
    ]
  }

  depends_on = [var.module_depends_on]
}

