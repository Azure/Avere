#cloud-config
#
write_files:
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${install_script}
    path: /opt/installcycle.sh
    permissions: '0644'

