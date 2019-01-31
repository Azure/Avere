#!/usr/bin/python3

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

# standard imports
import json
import logging
import os
import sys
from time import sleep

# from requirements.txt
import pytest
from scp import SCPClient
from sshtunnel import SSHTunnelForwarder

# local libraries
from lib.helpers import create_ssh_client, run_ssh_commands, wait_for_op


class TestVDBench:
    def test_vdbench_setup(self, mnt_nodes, ssh_con):  # noqa: F811
        log = logging.getLogger("test_vdbench_setup")
        commands = """
            sudo mkdir -p /nfs/node0/bootstrap
            cd /nfs/node0/bootstrap
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.vdbench.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/bootstrap.vdbench.sh
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/vdbench50407.zip https://avereimageswestus.blob.core.windows.net/vdbench/vdbench50407.zip
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/vdbenchVerify.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/vdbenchVerify.sh
            sudo chmod +x /nfs/node0/bootstrap/vdbenchVerify.sh
            /nfs/node0/bootstrap/vdbenchVerify.sh
            """.split("\n")
        run_ssh_commands(ssh_con, commands)

    def test_vdbench_deploy(self, test_vars):  # noqa: F811
        log = logging.getLogger("test_vdbench_deploy")
        atd = test_vars["atd_obj"]
        with open(test_vars["ssh_pub_key"], "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        with open("{}/src/client/vmas/azuredeploy.json".format(
                  os.environ["BUILD_SOURCESDIRECTORY"])) as tfile:
            atd.template = json.load(tfile)
        orig_params = atd.deploy_params.copy()
        atd.deploy_params = {
            "uniquename": atd.deploy_id,
            "sshKeyData": ssh_pub_key,
            "virtualNetworkResourceGroup": orig_params["virtualNetworkResourceGroup"],
            "virtualNetworkName": orig_params["virtualNetworkName"],
            "virtualNetworkSubnetName": orig_params["virtualNetworkSubnetName"],
            "nfsCommaSeparatedAddresses": ",".join(test_vars["cluster_vs_ips"]),
            "vmCount": 12,
            "nfsExportPath": "/msazure",
            "bootstrapScriptPath": "/bootstrap/bootstrap.vdbench.sh",
        }
        atd.deploy_name = "test_vdbench"
        deploy_result = wait_for_op(atd.deploy())
        test_vars["deploy_vd_outputs"] = deploy_result.properties.outputs

    def test_vdbench_run(self, test_vars):  # noqa: F811
        log = logging.getLogger("test_vdbench_run")
        node_ip = test_vars["deploy_vd_outputs"]["node_0_ip_address"]["value"]
        with SSHTunnelForwarder(
            test_vars["controller_ip"],
            ssh_username=test_vars["controller_user"],
            ssh_pkey=test_vars["ssh_priv_key"],
            remote_bind_address=(node_ip, 22),
        ) as ssh_tunnel:
            sleep(1)
            try:
                ssh_client = create_ssh_client(
                    test_vars["controller_user"],
                    "127.0.0.1",
                    ssh_tunnel.local_bind_port,
                )
                scp_client = SCPClient(ssh_client.get_transport())
                try:
                    scp_client.put(test_vars["ssh_priv_key"], r"~/.ssh/id_rsa")
                finally:
                    scp_client.close()
                commands = """
                    ~/copy_idrsa.sh
                    cd
                    ./run_vdbench.sh inmem.conf uniquestring1
                    """.split("\n")
                run_ssh_commands(ssh_client, commands)
            finally:
                ssh_client.close()


if __name__ == "__main__":
    pytest.main(sys.argv)
