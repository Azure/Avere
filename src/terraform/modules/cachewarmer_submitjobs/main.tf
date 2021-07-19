locals {
  mount_dir        = "/bcwsj"
  block_flag       = " -blockUntilWarm "
  no_block_flag    = ""
  warm_paths_array = [for i, z in var.warm_paths : setproduct([i], z)]
  warm_paths_sets  = flatten([for i in local.warm_paths_array : [for j in i : { export = j[0], path = j[1] }]])
  maxFileSizeBytes = var.maxFileSizeBytes == 0 ? "" : " -maxFileSizeBytes ${var.maxFileSizeBytes} "
  inclusion_csv    = var.inclusion_csv == null || length(var.inclusion_csv) == 0 ? "" : " -inclusionCsv \"${var.inclusion_csv}\" "
  exclusion_csv    = var.exclusion_csv == null || length(var.exclusion_csv) == 0 ? "" : " -exclusionCsv \"${var.exclusion_csv}\" "
}

resource "null_resource" "cachewarmer_submitmultiplejobs" {
  count = length(local.warm_paths_sets)

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
      "sudo /usr/local/bin/cachewarmer-jobsubmitter -storageAccountName ${var.storage_account} -storageAccountResourceGroup ${var.storage_account_rg} -queueNamePrefix ${var.queue_name_prefix} -warmTargetExportPath \"${local.warm_paths_sets[count.index].export}\" -warmTargetMountAddresses \"${var.warm_mount_addresses}\" -warmTargetPath \"${local.warm_paths_sets[count.index].path}\" ${local.inclusion_csv} ${local.exclusion_csv} ${local.maxFileSizeBytes} ${var.block_until_warm && count.index == 0 ? local.block_flag : local.no_block_flag}",
    ]
  }
}

