#!/bin/bash -ex

ADMIN_PASSWORD=${adminPassword} /usr/bin/hs-init-admin-pw

if [[ ${machineSize} == Standard_HB* ]]; then
  # sed -i "s/OS.EnableRDMA=n/OS.EnableRDMA=y" /etc/waagent.conf
  # echo "systemctl restart waagent" | at now +1 minutes
  # shutdown -r 1
fi

# hscli interface-update --node-name hs1Dsx1.hs1.azure  --interface-name ib0 --ip 172.16.0.21/16
# hscli interface-update --node-name hs1Dsx2.hs1.azure  --interface-name ib0 --ip 172.16.0.20/16
# hscli volume-update --internal-id 18 --additional-ip-add 172.16.0.21,,rdma
