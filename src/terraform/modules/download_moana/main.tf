locals {
  mount_path = "/b"

  prerequisites = [
    "set -x",
    "sudo wget --tries=12 --wait=5 -O /tmp/azcopy.tgz https://aka.ms/downloadazcopy-v10-linux",
    "sudo tar zxvf /tmp/azcopy.tgz -C /tmp",
    "sudo mv $(find /tmp/. -name azcopy) /usr/bin",
    "sudo rm -rf /tmp/azcopy*",
  ]

  prepare_path = [
    "sudo mkdir ${local.mount_path}",
    "sudo mount ${var.nfsfiler_address}:${var.nfsfiler_export_path} ${local.mount_path}",
    "sudo mkdir ${local.mount_path}/island",
  ]

  umount_path = [
    "sudo chmod -R 755 -R /b/island*",
    "sudo umount ${local.mount_path}",
    "sudo rmdir ${local.mount_path}",
  ]

  island_animation = var.island_animation_sas_url == "" ? [] : [
    "sudo azcopy cp '${var.island_animation_sas_url}' ${local.mount_path}/island-animation-v1.1.tgz",
    "sudo tar zxvf ${local.mount_path}/island-animation-v1.1.tgz -C ${local.mount_path}",
  ]

  island_basepackage = var.island_basepackage_sas_url == "" ? [] : [
    "sudo azcopy cp '${var.island_basepackage_sas_url}' ${local.mount_path}/island-basepackage-v1.1.tgz",
    "sudo tar zxvf ${local.mount_path}/island-basepackage-v1.1.tgz -C ${local.mount_path}",
  ]

  island_pbrt = var.island_pbrt_sas_url == "" ? [] : [
    "sudo azcopy cp '${var.island_pbrt_sas_url}' ${local.mount_path}/island-pbrt-v1.1.tgz",
    "sudo tar zxvf ${local.mount_path}/island-pbrt-v1.1.tgz -C ${local.mount_path}",
  ]
}

resource "null_resource" "download_moana" {
  connection {
    type        = "ssh"
    port        = var.ssh_port
    host        = var.node_address
    user        = var.admin_username
    password    = var.ssh_key_data != null && var.ssh_key_data != "" ? "" : var.admin_password
    private_key = var.ssh_key_data != null && var.ssh_key_data != "" ? file("~/.ssh/id_rsa") : null
  }

  provisioner "remote-exec" {
    inline = concat(local.prerequisites, local.prepare_path, local.island_animation, local.island_basepackage, local.island_pbrt, local.umount_path)
  }
}

