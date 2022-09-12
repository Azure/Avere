#!/bin/bash -ex

ADMIN_PASSWORD=${adminPassword} /usr/bin/hs-init-admin-pw

if [ ${machineSize} == Standard_HB* ]; then
    : # TODO: Enable InfiniBand (HBvX)
    # hscli interface-update --node-name  Hammerspace1Dsx1.Hammerspace1.azure  --interface-name ib0 --ip 172.16.0.21/16
    # hscli interface-update --node-name  Hammerspace1Dsx2.Hammerspace1.azure  --interface-name ib0 --ip 172.16.0.20/16
    # hscli volume-update --internal-id 18 --additional-ip-add 172.16.0.21,,rdma
fi
