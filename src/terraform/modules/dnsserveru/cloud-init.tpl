#cloud-config
#
write_files:
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${installcmd}
    path: /opt/install.sh
    permissions: '0755'
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${unboundconf}
    path: /opt/unbound.conf
    permissions: '0644'

runcmd:
 - set -x
 - if [ "${ssh_port}" -ne "22" ]; then sed -i 's/^#\?Port .*/Port ${ssh_port}/' /etc/ssh/sshd_config && systemctl restart sshd ; fi
