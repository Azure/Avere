locals {
    mount_dir = "/b"
    bootstrap_dir = "bootstrap"
    vmss_password_str = var.vmss_password == null ? "" : var.vmss_password
    vmss_ssh_public_key_str = var.vmss_ssh_public_key == null ? "" : var.vmss_ssh_public_key
    vmss_subnet_name_str = var.vmss_subnet_name == null ? "" : var.vmss_subnet_name 
    manager_bootstrap_path= "/${local.bootstrap_dir}/bootstrap.cachewarmer-manager.sh"
    env_vars = "export BOOTSTRAP_PATH=${local.mount_dir} && export JOB_MOUNT_ADDRESS=${var.jobMount_address} && export JOB_EXPORT_PATH=${var.job_export_path} && export JOB_BASE_PATH=${var.job_base_path} && export BOOTSTRAP_EXPORT_PATH=${var.bootstrap_export_path} && export BOOTSTRAP_MOUNT_ADDRESS=${var.bootstrap_mount_address} && export BOOTSTRAP_SCRIPT=${var.bootstrap_worker_script_path} && export VMSS_USERNAME=${var.vmss_user_name} && export VMSS_SSHPUBLICKEY='${local.vmss_ssh_public_key_str}' && export VMSS_PASSWORD='${local.vmss_password_str}' && export VMSS_SUBNET=${local.vmss_subnet_name_str}"
}

resource "null_resource" "install_cachewarmer_manager" {
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
      "if [ -f '/etc/centos-release' ]; then sudo yum -y install git nfs-utils ; else sudo apt-get install -y nfs-common ; fi",
      "sudo mkdir -p ${local.mount_dir}",
      "sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' ${var.bootstrap_mount_address}:${var.bootstrap_export_path} ${local.mount_dir}",
      "${local.env_vars} && sudo -E /bin/bash ${local.mount_dir}${var.bootstrap_manager_script_path}",
      "sudo umount ${local.mount_dir}",
      "sudo rmdir ${local.mount_dir}",
    ]
  }

  depends_on = [var.module_depends_on]
}


