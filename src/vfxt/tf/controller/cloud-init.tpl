#cloud-config
#
write_files:
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${averecmd}
    path: /usr/local/bin/averecmd
    permissions: '0755'
