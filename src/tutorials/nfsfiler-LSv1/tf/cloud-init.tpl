#cloud-config
#
write_files:
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${install_script}
    path: /opt/installnfs.sh
    permissions: '0644'

runcmd:
 - EXPORT_PATH=${export_path} EXPORT_OPTIONS="${export_options}" /bin/bash /opt/installnfs.sh 2>&1 | tee -a /var/log/installnfs.log