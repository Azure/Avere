locals {
  mount_dir = "/bcwpb"

  build_cachewarmer_lines = [
    "curl --retry 5 --retry-delay 5 --output /tmp/cachewarmer_build.sh https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/modules/cachewarmer_prepare_bootstrapdir/cachewarmer_build.sh",
    "chmod +x /tmp/cachewarmer_build.sh",
    ". /tmp/cachewarmer_build.sh",
  ]

  env_vars = "LOCAL_MOUNT_DIR=${local.mount_dir} BOOTSTRAP_MOUNT_ADDRESS=${var.bootstrap_mount_address} BOOTSTRAP_MOUNT_EXPORT=${var.bootstrap_export_path} BOOTSTRAP_SUBDIR=${var.bootstrap_subdir}"

  prepare_cachewarmer_bootstrap_lines = [
    "curl --retry 5 --retry-delay 5 --output /tmp/cachewarmer_prepare_bootstrap.sh https://raw.githubusercontent.com/Azure/Avere/main/src/terraform/modules/cachewarmer_prepare_bootstrapdir/cachewarmer_prepare_bootstrap.sh",
    "chmod +x /tmp/cachewarmer_prepare_bootstrap.sh",
    "${local.env_vars} /tmp/cachewarmer_prepare_bootstrap.sh",
  ]

  provisioner_lines = var.build_cachewarmer ? concat(local.build_cachewarmer_lines, local.prepare_cachewarmer_bootstrap_lines) : local.prepare_cachewarmer_bootstrap_lines
}

resource "null_resource" "build_cachewarmer_bootstrap" {
  connection {
    type        = "ssh"
    port        = var.jumpbox_ssh_port
    host        = var.jumpbox_address
    user        = var.jumpbox_username
    password    = var.jumpbox_ssh_key_data != null && var.jumpbox_ssh_key_data != "" ? "" : var.jumpbox_password
    private_key = var.jumpbox_ssh_key_data != null && var.jumpbox_ssh_key_data != "" ? file("~/.ssh/id_rsa") : null
  }

  provisioner "remote-exec" {
    inline = local.provisioner_lines
  }
}
