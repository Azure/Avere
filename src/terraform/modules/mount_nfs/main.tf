locals {
  bootstrap_script = "https://raw.githubusercontent.com/Azure/Avere/main/src/client/bootstrap.sh"
  bootstrap_dir    = "bootstrap"
}
resource "null_resource" "install_bootstrap" {
  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    type        = "ssh"
    port        = var.ssh_port
    host        = var.node_address
    user        = var.admin_username
    password    = var.ssh_key_data != null && var.ssh_key_data != "" ? "" : var.admin_password
    private_key = var.ssh_key_data != null && var.ssh_key_data != "" ? file("~/.ssh/id_rsa") : null
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.mount_dir}",
      "sudo echo \"${var.nfs_address}:${var.nfs_export_path}    ${var.mount_dir}    nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0\" | sudo tee -a /etc/fstab",
      "sudo mount -a",
    ]
  }
}
