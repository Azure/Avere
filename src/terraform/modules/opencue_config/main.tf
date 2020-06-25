locals {
    bootstrap_script = "https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/opencue/bootstrap.sh"
    mount_dir = "/b"
    bootstrap_dir = "bootstrap"
}
resource "null_resource" "install_bootstrap" {
  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
      type  = "ssh"
      host  = var.node_address
      user  = var.admin_username
      password = var.ssh_key_data != null && var.ssh_key_data != "" ? "" : var.admin_password
      private_key = var.ssh_key_data != null && var.ssh_key_data != "" ? file("~/.ssh/id_rsa") : null
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${local.mount_dir}",
      "sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' ${var.nfs_address}:${var.nfs_export_path} ${local.mount_dir}",
      "mkdir -p ${local.mount_dir}/${local.bootstrap_dir}",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/.bootstrap.sh ${local.bootstrap_script}",
      "mv ${local.mount_dir}/${local.bootstrap_dir}/.bootstrap.sh ${local.mount_dir}/${local.bootstrap_dir}/bootstrap.sh",
      "sudo umount ${local.mount_dir}",
      "sudo rmdir ${local.mount_dir}",
    ]
  }
}
