#!/usr/bin/python3
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

# standard imports
import json
import os
import logging
import sys
from time import sleep

# from requirements.txt
import pytest
from scp import SCPClient
from sshtunnel import SSHTunnelForwarder

# local libraries
from lib.helpers import create_ssh_client, run_ssh_commands, wait_for_op


class TestClientDocker:
    def test_client_docker_deploy(self, test_vars):  # noqa: F811
        log = logging.getLogger("test_vdbench_deploy")
        atd = test_vars["atd_obj"]
        with open(test_vars["ssh_pub_key"], "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        with open("{}/src/client/vmas/azuredeploy.json".format(
                  test_vars["build_root"])) as tfile:
            atd.template = json.load(tfile)
        atd.deploy_params = {
            "uniquename": atd.deploy_id,
            "sshKeyData": ssh_pub_key,
            "virtualNetworkResourceGroup": atd.resource_group,
            "virtualNetworkName": atd.deploy_id + "-vnet",
            "virtualNetworkSubnetName": atd.deploy_id + "-subnet",
            "nfsCommaSeparatedAddresses": ",".join(test_vars["cluster_vs_ips"]),
            "vmCount": 1,
            "nfsExportPath": "/msazure",
            "bootstrapScriptPath": "/bootstrap/bootstrap.vdbench.sh",
        }
        atd.deploy_name = "test_client_docker"
        deploy_result = wait_for_op(atd.deploy())
        test_vars["deploy_client_docker_outputs"] = deploy_result.properties.outputs

    def test_client_docker_run(self, test_vars):  # noqa: F811
        log = logging.getLogger("test_client_docker_run")
        node_ip = test_vars["deploy_client_docker_outputs"]["node_0_ip_address"]["value"]
        atd = test_vars["atd_obj"]
        with SSHTunnelForwarder(
            test_vars["public_ip"],
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
                    key_filename=test_vars["ssh_priv_key"]
                )
                scp_client = SCPClient(ssh_client.get_transport())
                try:
                    scp_client.put(test_vars["ssh_priv_key"], r"~/.ssh/id_rsa")
                finally:
                    scp_client.close()
                commands = """
                    cd
                    curl -fsSL https://get.docker.com -o get-docker.sh
                    sudo sh get-docker.sh
                    sudo docker login https://{0} -u {1} -p {2}
                    sudo docker pull {0}/test1

                    echo "export STORAGEACT={3}" >> ~/.bashrc
                    echo "export MGMIP={4}" >> ~/.bashrc
                    echo "export KEY={5}" >> ~/.bashrc
                    """.format(os.environ["dockerRegistry"], os.environ["dockerUsername"], os.environ["dockerPassword"], atd.deploy_id + "sa", test_vars["public_ip"], os.environ["AZURE_CLIENT_SECRET"]).split("\n")
                run_ssh_commands(ssh_client, commands)
            finally:
                ssh_client.close()

#sudo docker run {0}/test
if __name__ == "__main__":
    pytest.main(sys.argv)

