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
import tempfile
from time import sleep

# from requirements.txt
import pytest
from scp import SCPClient
from sshtunnel import SSHTunnelForwarder

# local libraries
from lib.helpers import create_ssh_client, run_ssh_command, run_ssh_commands, wait_for_op


class TestRegressionClientSetup:
    def test_reg_clients_bootstrap_setup(self, mnt_nodes, ssh_con, scp_con, test_vars):  # noqa: E501, F811
        log = logging.getLogger("test_reg_clients_bootstrap_setup")

        # Make the bootstrap directory.
        boot_dir = "/nfs/node0/bootstrap"
        run_ssh_command(ssh_con, "sudo mkdir -p {}".format(boot_dir))

        # The bootstrap file contains some placeholder tags for data that we
        # don't know until after deployment and also for some secrets. This
        # This dict maps those tags to the values they should eventually have.
        replacements = {
            '<git_username>': os.environ["GIT_UN"],
            '<git_password>': os.environ["GIT_PAT"]
        }

        for boot_file in ["bootstrap.reg_client.sh", "bootstrap.reg_client_staf.sh"]:
            # Read the local copy of the bootstrap file into memory.
            base_file = "{0}/test/{1}".format(test_vars["build_root"], boot_file)
            with open(base_file, "rt") as fin:
                base_file_content = fin.read()

            # Replace all instances of placeholder tags with their values.
            for k, v in replacements.items():
                base_file_content = base_file_content.replace(k, v)

            # Create a temporary file and copy the in-memory (post-replace)
            # bootstrap file into that temporary file.
            temp_file = tempfile.NamedTemporaryFile(mode='w+t', delete=False)
            log.debug("Temporary file created: {}".format(temp_file.name))
            temp_file.write(base_file_content)
            temp_file.close()

            # Copy the temp file to the controller (in the user's home dir).
            scp_con.put(temp_file.name, "~/{}".format(boot_file))
            os.remove(temp_file.name)
            log.debug("Temporary file deleted: {}".format(temp_file.name))

            # Move the bootstrap file from the controller user's home dir to
            # the bootstrap directory (root privileges required).
            run_ssh_command(ssh_con, "sudo mv ~/{0} {1}/.".format(boot_file, boot_dir))

        # Copy and move the pip.conf file.
        scp_con.put("{0}/pip.conf".format(test_vars["build_root"], "~/."))
        run_ssh_command(ssh_con, "sudo mv ~/pip.conf {0}/.".format(boot_dir))

        log.debug("Copying SSH keys to the controller")
        scp_con.put(test_vars["ssh_priv_key"], "~/.ssh/.")
        scp_con.put(test_vars["ssh_pub_key"], "~/.ssh/.")

    def test_reg_clients_deploy(self, test_vars):  # noqa: F811
        log = logging.getLogger("test_reg_clients_deploy")
        atd = test_vars["atd_obj"]
        with open(test_vars["ssh_pub_key"], "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        with open("{}/src/client/vmas/azuredeploy.reg_clients.json".format(
                  test_vars["build_root"])) as tfile:
            atd.template = json.load(tfile)
        atd.deploy_params = {
            "uniquename": atd.deploy_id,
            "sshKeyData": ssh_pub_key,
            "virtualNetworkResourceGroup": atd.resource_group,
            "virtualNetworkName": atd.deploy_id + "-vnet",
            "virtualNetworkSubnetName": atd.deploy_id + "-subnet",
            "nfsCommaSeparatedAddresses": ",".join(test_vars["cluster_vs_ips"]),
            "vmCount": 2,
            "nfsExportPath": "/msazure",
            "bootstrapScriptPath": "/bootstrap/bootstrap.reg_client.sh",
            "bootstrapScriptStafPath": "/bootstrap/bootstrap.reg_client_staf.sh",
        }
        atd.deploy_name = "test_reg_clients_deploy"
        deploy_result = wait_for_op(atd.deploy())
        test_vars["reg_client_outputs"] = deploy_result.properties.outputs

    # def test_client_docker_run(self, test_vars):  # noqa: F811
    #     log = logging.getLogger("test_client_docker_run")
    #     node_ip = test_vars["deploy_client_docker_outputs"]["node_0_ip_address"]["value"]
    #     atd = test_vars["atd_obj"]
    #     cluster_mgmt_ip = test_vars["cluster_mgmt_ip"]
    #     with SSHTunnelForwarder(
    #         test_vars["public_ip"],
    #         ssh_username=test_vars["controller_user"],
    #         ssh_pkey=test_vars["ssh_priv_key"],
    #         remote_bind_address=(node_ip, 22),
    #     ) as ssh_tunnel:
    #         sleep(1)
    #         try:
    #             ssh_client = create_ssh_client(
    #                 test_vars["controller_user"],
    #                 "127.0.0.1",
    #                 ssh_tunnel.local_bind_port,
    #                 key_filename=test_vars["ssh_priv_key"]
    #             )
    #             scp_client = SCPClient(ssh_client.get_transport())
    #             try:
    #                 scp_client.put(test_vars["ssh_priv_key"], r"~/.ssh/id_rsa")
    #             finally:
    #                 scp_client.close()
    #             commands = """
    #                 cd
    #                 curl -fsSL https://get.docker.com -o get-docker.sh
    #                 sudo sh get-docker.sh
    #                 sudo docker login https://{0} -u {1} -p {2}
    #                 sudo docker pull {0}/test

    #                 echo "export STORAGEACT='{3}'" >> ~/.bashrc
    #                 echo "export MGMIP='{4}'" >> ~/.bashrc
    #                 echo "export SA_KEY='{5}'" >> ~/.bashrc
    #                 echo "export CLUSTER_MGMT_IP='{6}'" >> ~/.bashrc
    #                 echo "export ADMIN_PW='{7}'" >> ~/.bashrc
    #                 """.format(os.environ["dockerRegistry"], os.environ["dockerUsername"], os.environ["dockerPassword"], atd.deploy_id + "sa", test_vars["public_ip"], os.environ["SA_KEY"], cluster_mgmt_ip, os.environ["AVERE_ADMIN_PW"]).split("\n")
    #             run_ssh_commands(ssh_client, commands)
    #         finally:
    #             ssh_client.close()

if __name__ == "__main__":
    pytest.main(sys.argv)

