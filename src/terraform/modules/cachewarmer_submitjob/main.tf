resource "null_resource" "install_cachewarmer_manager" {
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
      "if [ -f '/etc/centos-release' ]; then sudo yum -y install git nfs-utils ; else sudo apt-get install -y nfs-common ; fi",
      "sudo /usr/local/bin/cachewarmer-jobsubmitter -jobBasePath ${var.job_base_path} -jobExportPath ${var.job_export_path} -jobMountAddress ${var.jobMount_address} -warmTargetExportPath ${var.warm_target_export_path} -warmTargetMountAddresses \"${var.warm_mount_addresses}\" -warmTargetPath \"${var.warm_target_path}\"",
    ]
  }
}
