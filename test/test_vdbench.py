#!/usr/bin/python3

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

import json
import os
from time import sleep

import pytest
from scp import SCPClient

from lib import helpers
from lib.pytest_fixtures import (group_vars, scp_client, ssh_client,
                                 vserver_ip_list)
from sshtunnel import SSHTunnelForwarder


class TestVDBench:
    def test_vdbench_setup(self, group_vars, ssh_client):
        # TODO: Ensure nodes are mounted on controller. (fixture?)
        commands = """
            sudo mkdir -p /nfs/node0/bootstrap
            cd /nfs/node0/bootstrap
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.vdbench.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/bootstrap.vdbench.sh
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/vdbench50407.zip https://avereimageswestus.blob.core.windows.net/vdbench/vdbench50407.zip
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/vdbenchVerify.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/vdbenchVerify.sh
            sudo chmod +x /nfs/node0/bootstrap/vdbenchVerify.sh
            /nfs/node0/bootstrap/vdbenchVerify.sh
            """.split("\n")
        helpers.run_ssh_commands(ssh_client, commands)

    def test_vdbench_deploy(self, group_vars, vserver_ip_list):
        td = group_vars["atd_obj"]
        with open(os.path.expanduser(r"~/.ssh/id_rsa.pub"), "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        with open("{}/src/client/vmas/azuredeploy.json".format(
                  os.environ["BUILD_SOURCESDIRECTORY"])) as tfile:
            td.template = json.load(tfile)
        orig_params = td.deploy_params.copy()
        td.deploy_params = {
            "uniquename": td.deploy_id,
            "sshKeyData": ssh_pub_key,
            "virtualNetworkResourceGroup": orig_params["virtualNetworkResourceGroup"],
            "virtualNetworkName": orig_params["virtualNetworkName"],
            "virtualNetworkSubnetName": orig_params["virtualNetworkSubnetName"],
            "nfsCommaSeparatedAddresses": ",".join(vserver_ip_list),
            "vmCount": 12,
            "nfsExportPath": "/msazure",
            "bootstrapScriptPath": "/bootstrap/bootstrap.vdbench.sh",
        }
        td.deploy_name = "test_vdbench"
        deploy_result = helpers.wait_for_op(td.deploy())
        group_vars["deploy_vd_outputs"] = deploy_result.properties.outputs

    def test_vdbench_template_run(self, group_vars):
        node_ip = group_vars["deploy_vd_outputs"]["nodE_0_IP_ADDRESS"]["value"]
        with SSHTunnelForwarder(
            group_vars["controller_ip"],
            ssh_username=group_vars["controller_user"],
            ssh_pkey=os.path.expanduser(r"~/.ssh/id_rsa"),
            remote_bind_address=(node_ip, 22),
        ) as ssh_tunnel:
            sleep(1)
            try:
                ssh_client = helpers.create_ssh_client(
                    group_vars["controller_user"],
                    "127.0.0.1",
                    ssh_tunnel.local_bind_port,
                )
                scp_client = SCPClient(ssh_client.get_transport())
                try:
                    scp_client.put(os.path.expanduser(r"~/.ssh/id_rsa"),
                                   r"~/.ssh/id_rsa")
                finally:
                    scp_client.close()
                commands = """
                    ~/copy_idrsa.sh
                    cd
                    """.split("\n")
                # ./run_vdbench.sh inmem.conf uniquestring1  # TODO: reenable
                helpers.run_ssh_commands(ssh_client, commands)
            finally:
                ssh_client.close()


if __name__ == "__main__":
    pytest.main()
