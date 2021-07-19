locals {
  mount_dir = "/b"
  proxy_env = (var.proxy == null || var.proxy == "") ? "" : "export http_proxy=${var.proxy} && export https_proxy=${var.proxy} && export no_proxy=169.254.169.254 &&"
  env_vars  = "${local.proxy_env} export BOOTSTRAP_PATH=${local.mount_dir} && export STORAGE_ACCOUNT_RESOURCE_GROUP='${var.storage_account_rg}' && export STORAGE_ACCOUNT=${var.storage_account} && export QUEUE_PREFIX=${var.queue_name_prefix}  && export BOOTSTRAP_SCRIPT=${var.bootstrap_worker_script_path}"
}

resource "null_resource" "install_cachewarmer_worker" {
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
      "sudo mkdir -p ${local.mount_dir}",
      "sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' ${var.bootstrap_mount_address}:${var.bootstrap_export_path} ${local.mount_dir}",
      "${local.env_vars} && sudo -E /bin/bash ${local.mount_dir}${var.bootstrap_worker_script_path}",
      "sudo umount ${local.mount_dir}",
      "sudo rmdir ${local.mount_dir}",
    ]
  }
}


