#cloud-config
#
write_files:
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${installcmd}
    path: /opt/install.sh
    permissions: '0755'
