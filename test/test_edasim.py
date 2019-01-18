#!/usr/bin/python3

"""
Driver for testing edasim
"""

import json
import os
from time import sleep
import logging
import pytest
from scp import SCPClient

from sshtunnel import SSHTunnelForwarder

from lib import helpers
from lib.pytest_fixtures import (averecmd_params, mnt_nodes,  # noqa: F401
                                 resource_group, storage_account, event_hub,
                                 scp_cli, ssh_con, test_vars, vs_ips)

# logging.basicConfig(level=logging.DEBUG)

class TestEdasim:
    # def test_download_go(self):
    #     commands = """
    #         wget https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz
    #         tar xvf go1.11.2.linux-amd64.tar.gz
    #         sudo chown -R root:root ./go
    #         sudo mv go /usr/local
    #         mkdir ~/gopath
    #         echo "export GOPATH=$HOME/gopath" >> ~/.profile
    #         echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> ~/.profile
    #         source ~/.profile
    #         rm go1.11.2.linux-amd64.tar.gz
    #         """.split("\n")
    #     helpers.run_ssh_commands(ssh_con, commands)
    def test_storage_account(self, test_vars, resource_group, storage_account, ssh_con):
        td = test_vars["atd_obj"]
        storage_keys = td.st_client.storage_accounts.list_keys(
            resource_group.name,
            storage_account.name)
        storage_keys = {v.key_name: v.value for v in storage_keys.keys}
        key = storage_keys['key1']
        print("storage_account = {}".format(storage_account.name))
        print("key = {}".format(key))
        commands = """
            export AZURE_STORAGE_ACCOUNT= {0}
            export AZURE_STORAGE_ACCOUNT_KEY={1}
            """.format(storage_account.name, key).split("\n")
        helpers.run_ssh_commands(ssh_con, commands)

    # def test_event_hub(self, test_vars):
    #     client = self.event_hub
    #     receiver = client.add_receiver("$default", "0", operation='/messages/events')
    #     try:
    #         client.run()
    #         eh_info = client.get_eventhub_info()
    #         print(eh_info)
    #     finally:
    #         print("whatever")
    # def test_edasim_setup(self, mnt_nodes, ssh_con):  # noqa: F811
    #     commands = """
    #         mkdir /nfs/node0/bootstrap
    #         cd /nfs/node0/bootstrap
    #         curl --retry 5 --retry-delay 5 -o bootstrap.jobsubmitter.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.jobsubmitter.sh
    #         curl --retry 5 --retry-delay 5 -o bootstrap.orchestrator.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.orchestrator.sh
    #         curl --retry 5 --retry-delay 5 -o bootstrap.onpremjobuploader.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.onpremjobuploader.sh
    #         curl --retry 5 --retry-delay 5 -o bootstrap.worker.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.worker.sh
    #         mkdir /nfs/node0/bootstrap/edasim
    #         cp $GOPATH/bin/* /nfs/node0/bootstrap/edasim
    #         mkdir /nfs/node0/bootstrap/rsyslog
    #         cd /nfs/node0/bootstrap/rsyslog
    #         curl --retry 5 --retry-delay 5 -o 33-jobsubmitter.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/33-jobsubmitter.conf
    #         curl --retry 5 --retry-delay 5 -o 30-orchestrator.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/30-orchestrator.conf
    #         curl --retry 5 --retry-delay 5 -o 31-worker.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/31-worker.conf
    #         curl --retry 5 --retry-delay 5 -o 32-onpremjobuploader.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/32-onpremjobuploader.conf
    #         mkdir /nfs/node0/bootstrap/systemd
    #         cd /nfs/node0/bootstrap/systemd
    #         curl --retry 5 --retry-delay 5 -o jobsubmitter.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/jobsubmitter.service
    #         curl --retry 5 --retry-delay 5 -o onpremjobuploader.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/onpremjobuploader.service
    #         curl --retry 5 --retry-delay 5 -o orchestrator.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/orchestrator.service
    #         curl --retry 5 --retry-delay 5 -o worker.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/worker.service
    #         """.split("\n")
    #     helpers.run_ssh_commands(ssh_con, commands)

    # def test_edasim_deploy(self, test_vars, vs_ips):  # noqa: F811
    #     td = test_vars["atd_obj"]
    #     with open(os.path.expanduser(r"~/.ssh/id_rsa.pub"), "r") as ssh_pub_f:
    #         ssh_pub_key = ssh_pub_f.read()
    #     with open("{}/src/client/vmas/azuredeploy.json".format(
    #               os.environ["BUILD_SOURCESDIRECTORY"])) as tfile:
    #         td.template = json.load(tfile)
    #     orig_params = td.deploy_params.copy()
    #     td.deploy_params = {
    #         "uniquename": td.deploy_id,
    #         "sshKeyData": ssh_pub_key,
    #         "virtualNetworkResourceGroup": orig_params["virtualNetworkResourceGroup"],
    #         "virtualNetworkName": orig_params["virtualNetworkName"],
    #         "virtualNetworkSubnetName": orig_params["virtualNetworkSubnetName"],
    #         "nfsCommaSeparatedAddresses": ",".join(vs_ips),
    #         "vmCount": 12,
    #         "nfsExportPath": "/msazure",
    #         "bootstrapScriptPath": "/bootstrap/bootstrap.vdbench.sh",
    #     }
    #     td.deploy_name = "test_edasim"
    #     deploy_result = helpers.wait_for_op(td.deploy())
    #     test_vars["deploy_vd_outputs"] = deploy_result.properties.outputs




if __name__ == "__main__":
    pytest.main()
