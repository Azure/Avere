#cloud-config
#
runcmd:
 - set -x
 - if [ "${ssh_port}" -ne "22" ]; then sed -i 's/^#\?Port .*/Port ${ssh_port}/' /etc/ssh/sshd_config && systemctl restart sshd ; fi
