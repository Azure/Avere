locals {
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
      "if [ -f '/etc/centos-release' ]; then sudo yum -y install git nfs-utils ; else sudo apt-get install -y nfs-common ; fi",
      "wget -O ~/go.tgz https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz",
      "tar xvf ~/go.tgz",
      "rm ~/go.tgz",
      "sudo chown -R root:root ~/go",
      "sudo mv go /usr/local",
      "mkdir ~/gopath"
      "echo \"export GOPATH=$HOME/gopath\" >> ~/.profile",
      "echo \"export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin\" >> ~/.profile",
      "source ~/.profile && cd $GOPATH && go get -v github.com/Azure/Avere/src/go/...",
      "sudo mkdir -p ${local.mount_dir}",
      "sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' ${var.nfs_address}:${var.nfs_export_path} ${local.mount_dir}",
      "mkdir -p ${local.mount_dir}/${local.bootstrap_dir}",
      "mkdir -p ${local.mount_dir}/${local.bootstrap_dir}/rsyslog",
      "mkdir -p ${local.mount_dir}/${local.bootstrap_dir}/systemd",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/bootstrap.cachewarmer-manager.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-manager.sh",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/bootstrap.cachewarmer-worker.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-worker.sh",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/35-cachewarmer-manager.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/35-cachewarmer-manager.conf",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/rsyslog/36-cachewarmer-worker.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/36-cachewarmer-worker.conf",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-manager.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-manager.service",
      "curl --retry 5 --retry-delay 5 -o ${local.mount_dir}/${local.bootstrap_dir}/systemd/cachewarmer-worker.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-worker.service",
      "sudo umount ${local.mount_dir}",
      "sudo rmdir ${local.mount_dir}",
    ]
  }
}
