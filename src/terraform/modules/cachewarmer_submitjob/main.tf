locals {
  mount_dir        = "/b"
  block_flag       = var.block_until_warm ? " -blockUntilWarm " : ""
  maxFileSizeBytes = var.maxFileSizeBytes == 0 ? "" : " -maxFileSizeBytes ${var.maxFileSizeBytes} "
}

resource "null_resource" "cachewarmer_submitjob" {
  connection {
    type        = "ssh"
    port        = var.jumpbox_ssh_port
    host        = var.jumpbox_address
    user        = var.jumpbox_username
    password    = var.jumpbox_ssh_key_data != null && var.jumpbox_ssh_key_data != "" ? "" : var.jumpbox_password
    private_key = var.jumpbox_ssh_key_data != null && var.jumpbox_ssh_key_data != "" ? file("~/.ssh/id_rsa") : null
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sudo /usr/local/bin/cachewarmer-jobsubmitter -storageAccountName ${var.storage_account} -storageAccountResourceGroup ${var.storage_account_rg} -queueNamePrefix ${var.queue_name_prefix} -warmTargetExportPath ${var.warm_target_export_path} -warmTargetMountAddresses \"${var.warm_mount_addresses}\" -warmTargetPath \"${var.warm_target_path}\" -inclusionCsv \"${var.inclusion_csv}\" -exclusionCsv \"${var.exclusion_csv}\" ${local.maxFileSizeBytes} ${local.block_flag}",
    ]
  }
}

