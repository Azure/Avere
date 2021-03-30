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
 - set -x
 - SEARCH_DOMAIN="${search_domain}" /bin/bash /opt/installnfs.sh 2>&1 | tee -a /var/log/installnfs.log