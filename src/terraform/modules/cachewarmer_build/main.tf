locals {
  mount_dir              = "/b"
  bootstrap_dir          = "bootstrap"
  manager_bootstrap_path = "/${local.bootstrap_dir}/bootstrap.cachewarmer-manager.sh"
  worker_bootstrap_path  = "/${local.bootstrap_dir}/bootstrap.cachewarmer-worker.sh"
}

resource "null_resource" "build_cachewarmer_bootstrap" {
  count = var.deploy_cachewarmer ? 1 : 0

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
      "set -x",
      "if [ -f '/etc/centos-release' ]; then sudo yum -y install git nfs-utils ; else sudo apt-get install -y nfs-common ; fi",
      "wget -O ~/go.tgz https://golang.org/dl/go1.14.4.linux-amd64.tar.gz",
      "tar zxf ~/go.tgz",
      "sudo chown -R root:root ~/go",
      "sudo rm -rf /usr/local/go",
      "sudo mv go /usr/local",
      "rm ~/go.tgz",
      "rm -rf ~/gopath",
      "mkdir ~/gopath",
      "sudo mkdir -p ${local.mount_dir}",
      "sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' ${var.bootstrap_mount_address}:${var.bootstrap_export_path} ${local.mount_dir}",
      "sudo mkdir -p ${local.mount_dir}/${local.bootstrap_dir}",
      "sudo mkdir -p ${local.mount_dir}/${local.bootstrap_dir}/cachewarmerbin",
      "echo \"export GOPATH=$HOME/gopath\" >> ~/.profile",
      "echo \"export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin\" >> ~/.profile",
      "/bin/bash -c 'source ~/.profile && cd $GOPATH && go get github.com/Azure/Avere/src/go/... && sudo cp $GOPATH/bin/cachewarmer-* ${local.mount_dir}/${local.bootstrap_dir}/cachewarmerbin'",
      "sudo mkdir -p ${local.mount_dir}/${local.bootstrap_dir}/rsyslog",
      "sudo mkdir -p ${local.mount_dir}/${local.bootstrap_dir}/systemd",
      "sudo rm -f ${local.mount_dir}${local.manager_bootstrap_path}",
      "sudo rm -f ${local.mount_dir}${local.worker_bootstrap_path}",
      "sudo rm -f ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/35-cachewarmer-manager.conf",
      "sudo rm -f ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/36-cachewarmer-worker.conf",
      "sudo rm -f ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-manager.service",
      "sudo rm -f ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-worker.service",
      "sudo curl --retry 5 --retry-delay 5 -o ${local.mount_dir}${local.manager_bootstrap_path} https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-manager.sh",
      "sudo curl --retry 5 --retry-delay 5 -o ${local.mount_dir}${local.worker_bootstrap_path} https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-worker.sh",
      "sudo curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/35-cachewarmer-manager.conf https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/35-cachewarmer-manager.conf",
      "sudo curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/36-cachewarmer-worker.conf https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/36-cachewarmer-worker.conf",
      "sudo curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-manager.service https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-manager.service",
      "sudo curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-worker.service https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-worker.service",
      "sudo umount ${local.mount_dir}",
      "sudo rmdir ${local.mount_dir}",
    ]
  }

  depends_on = [var.module_depends_on]
}
