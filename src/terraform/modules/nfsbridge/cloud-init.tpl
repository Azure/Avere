#cloud-config
#
write_files:
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${installcmd}
    path: /opt/install.sh
    permissions: '0755'

runcmd:
 - set -x
 - if [ "${ssh_port}" -ne "22" ]; then sed -i 's/^#\?Port .*/Port ${ssh_port}/' /etc/ssh/sshd_config && semanage port -a -t ssh_port_t -p tcp ${ssh_port} && systemctl restart sshd ; fi
