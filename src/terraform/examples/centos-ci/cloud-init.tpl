#cloud-config
#
# from https://cloudinit.readthedocs.io/en/latest/topics/examples.html#writing-out-arbitrary-files
write_files:
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${foreman_file}
    path: /etc/cloud/cloud.config.d/20-foreman.cfg
    permissions: '0644'
 -  encoding: gzip
    owner: root:root
    content: !!binary |
            ${example_file_b64}
    path: /opt/examplefile.txt
    permissions: '0644'

# runcmd example here: https://cloudinit.readthedocs.io/en/latest/topics/examples.html#run-commands-on-first-boot
runcmd:
 - set -x
 # the below is not needed, but shows an example of execution
 - echo "running some script" | tee -a /var/log/install.log