locals {
  mount_dir = "/b"
  block_flag = var.block_until_warm ? " -blockUntilWarm " : ""
}

resource "null_resource" "cachewarmer_submitjob" {
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
      "sudo /usr/local/bin/cachewarmer-jobsubmitter -jobBasePath ${var.job_base_path} -jobExportPath ${var.job_export_path} -jobMountAddress ${var.jobMount_address} -warmTargetExportPath ${var.warm_target_export_path} -warmTargetMountAddresses \"${var.warm_mount_addresses}\" -warmTargetPath \"${var.warm_target_path}\" ${local.block_flag}",
    ]
  }

  depends_on = [var.module_depends_on]
}

