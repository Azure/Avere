locals {
    mount_dir = "/b"
    bootstrap_dir = "boostrap"
    manager_bootstrap_path= "/${bootstrap_dir}/bootstrap.cachewarmer-manager.sh"
    worker_bootstrap_path= "/${bootstrap_dir}/bootstrap.cachewarmer-worker.sh"
    env_vars = "export BOOTSTRAP_PATH=${var.mount_dir} && export JOB_MOUNT_ADDRESS=${var.jobMount_address} && export JOB_EXPORT_PATH=${var.job_export_path} && export JOB_BASE_PATH=${var.job_base_path} && export BOOTSTRAP_EXPORT_PATH=${var.bootstrap_export_path} && export BOOTSTRAP_MOUNT_ADDRESS=${var.bootstrap_mount_address} && export BOOTSTRAP_SCRIPT=${local.worker_bootstrap_path} && export VMSS_USERNAME=${var.vmss_user_name} && export VMSS_SSHPUBLICKEY='${var.vmss_ssh_public_key}' && export VMSS_PASSWORD='${var.vmss_password}' && export VMSS_SUBNET=${var.vmss_subnet_name}"
}
resource "null_resource" "install_bootstrap" {
  connection {
      type  = "ssh"
      host  = var.node_address
      user  = var.admin_username
      password = var.ssh_key_data != null && var.ssh_key_data != "" ? "" : var.admin_password
      private_key = var.ssh_key_data != null && var.ssh_key_data != "" ? file("~/.ssh/id_rsa") : null
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"if [ -f '/etc/centos-release' ]; then sudo yum -y install git nfs-utils ; else sudo apt-get install -y nfs-common ; fi\" >> ~/cmd.txt",
      "echo \"wget -O ~/go.tgz https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz\" >> ~/cmd.txt",
      "echo \"tar xvf ~/go.tgz\" >> ~/cmd.txt",
      "echo \"rm ~/go.tgz\" >> ~/cmd.txt",
      "echo \"sudo chown -R root:root ~/go\" >> ~/cmd.txt",
      "echo \"sudo mv go /usr/local\" >> ~/cmd.txt",
      "echo \"mkdir ~/gopath\" >> ~/cmd.txt",
      "echo \"echo \"export GOPATH=$HOME/gopath\" >> ~/.profile\" >> ~/cmd.txt",
      "echo \"echo \"export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin\" >> ~/.profile\" >> ~/cmd.txt",
      "echo \"source ~/.profile && cd $GOPATH && go get -v github.com/Azure/Avere/src/go/...\" >> ~/cmd.txt",
      "echo \"sudo mkdir -p ${local.mount_dir}\" >> ~/cmd.txt",
      "echo \"sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' ${var.bootstrap_mount_address}:${var.bootstrap_export_path} ${local.mount_dir}\" >> ~/cmd.txt",
      "echo \"mkdir -p ${local.mount_dir}/${local.bootstrap_dir}\" >> ~/cmd.txt",
      "echo \"mkdir -p ${local.mount_dir}/${local.bootstrap_dir}/rsyslog\" >> ~/cmd.txt",
      "echo \"mkdir -p ${local.mount_dir}/${local.bootstrap_dir}/systemd\" >> ~/cmd.txt",
      "echo \"curl --retry 5 --retry-delay 5 -o ${local.mount_dir}${local.manager_bootstrap_path} https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-manager.sh\" >> ~/cmd.txt",
      "echo \"curl --retry 5 --retry-delay 5 -o ${local.mount_dir}${local.worker_bootstrap_path} https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-worker.sh\" >> ~/cmd.txt",
      "echo \"curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/35-cachewarmer-manager.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/35-cachewarmer-manager.conf\" >> ~/cmd.txt",
      "echo \"curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/36-cachewarmer-worker.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/36-cachewarmer-worker.conf\" >> ~/cmd.txt",
      "echo \"curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-manager.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-manager.service\" >> ~/cmd.txt",
      "echo \"curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-worker.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-worker.service\" >> ~/cmd.txt",
      "echo \"${env_vars} && sudo -E /bin/bash ${local.mount_dir}${local.manager_bootstrap_path}\" >> ~/cmd.txt",
      "echo \"sudo umount ${local.mount_dir}\" >> ~/cmd.txt",
      "echo \"sudo rmdir ${local.mount_dir}\" >> ~/cmd.txt",
    ]
  }
}

  /*provisioner "remote-exec" {
    inline = [
      "if [ -f '/etc/centos-release' ]; then sudo yum -y install git nfs-utils ; else sudo apt-get install -y nfs-common ; fi",
      "wget -O ~/go.tgz https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz",
      "tar xvf ~/go.tgz",
      "rm ~/go.tgz",
      "sudo chown -R root:root ~/go",
      "sudo mv go /usr/local",
      "mkdir ~/gopath",
      "echo \"export GOPATH=$HOME/gopath\" >> ~/.profile",
      "echo \"export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin\" >> ~/.profile",
      "source ~/.profile && cd $GOPATH && go get -v github.com/Azure/Avere/src/go/...",
      "sudo mkdir -p ${local.mount_dir}",
      "sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' ${var.bootstrap_mount_address}:${var.bootstrap_export_path} ${local.mount_dir}",
      "mkdir -p ${local.mount_dir}/${local.bootstrap_dir}",
      "mkdir -p ${local.mount_dir}/${local.bootstrap_dir}/rsyslog",
      "mkdir -p ${local.mount_dir}/${local.bootstrap_dir}/systemd",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}${local.manager_bootstrap_path} https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-manager.sh",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}${local.worker_bootstrap_path} https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-worker.sh",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/35-cachewarmer-manager.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/35-cachewarmer-manager.conf",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/36-cachewarmer-worker.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/36-cachewarmer-worker.conf",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-manager.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-manager.service",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-worker.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-worker.service",
      "${env_vars} && sudo -E /bin/bash ${local.mount_dir}${local.manager_bootstrap_path}",
      "sudo umount ${local.mount_dir}",
      "sudo rmdir ${local.mount_dir}",
    ]
  }
}*/
