#cloud-config
#
write_files:
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${averecmd}
    path: /usr/local/bin/averecmd
    permissions: '0755'
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${msazure_patch1}
    path: /usr/local/lib/python2.7/dist-packages/vFXT/msazure.py.patch1
    permissions: '0755'

runcmd:
 - patch --quiet --forward /usr/local/lib/python2.7/dist-packages/vFXT/msazure.py /usr/local/lib/python2.7/dist-packages/vFXT/msazure.py.patch1