#cloud-config
#
write_files:
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${msazure_patchidentity}
    path: /usr/local/lib/python3.6/dist-packages/vFXT/msazure.py.patchidentity
    permissions: '0755'
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${vfxtpy_patchzone}
    path: /usr/local/bin/vfxt.py.patchzone
    permissions: '0755'
 
runcmd:
 - set -x
 - rm -f /usr/local/bin/terraform-provider-avere
 - patch --quiet --forward /usr/local/lib/python3.6/dist-packages/vFXT/msazure.py /usr/local/lib/python3.6/dist-packages/vFXT/msazure.py.patchidentity
 - patch --quiet --forward /usr/local/bin/vfxt.py /usr/local/bin/vfxt.py.patchzone
 - if [ "${ssh_port}" -ne "22" ]; then sed -i 's/^#\?Port .*/Port ${ssh_port}/' /etc/ssh/sshd_config && systemctl restart sshd ; fi
