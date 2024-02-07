#!/usr/bin/python3
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

"""
Sets up VM clients for vFXT regression testing.
"""

# standard imports
import json
import logging
import os
import sys
import tempfile

# from requirements.txt
import pytest
from fabric import Connection
from paramiko.ssh_exception import NoValidConnectionsError
from scp import SCPClient

# local libraries
from lib.helpers import (get_unused_local_port, run_ssh_command,
                         run_ssh_commands, wait_for_op)


class TestRegressionClientSetup:
    def test_reg_clients_bootstrap_setup(self, mnt_nodes, ssh_con, scp_con, test_vars):  # noqa: E501, F811
        log = logging.getLogger("test_reg_clients_bootstrap_setup")

        # Make the bootstrap directory.
        boot_dir = "/nfs/node0/bootstrap"
        boot_file = "bootstrap.reg_client.sh"
        run_ssh_command(ssh_con, "sudo mkdir -p {}".format(boot_dir))

        # The bootstrap file contains some placeholder tags for data that we
        # don't know until after deployment and also for some secrets. This
        # This dict maps those tags to the values they should eventually have.
        replacements = {
            '<git_username>': os.environ["GIT_UN"],
            '<git_password>': os.environ["GIT_PAT"],
            '<pipelines_sa>': os.environ["PIPELINES_DATA_STORAGE_ACCOUNT"],
            '<pipelines_sa_key>': os.environ["PIPELINES_DATA_STORAGE_ACCOUNT_KEY"]
        }

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
        # Not needed for automation, but useful for manual intervention.
        scp_con.put(test_vars["ssh_priv_key"], "~/.ssh/id_rsa")
        scp_con.put(test_vars["ssh_pub_key"], "~/.ssh/id_rsa.pub")

    def test_reg_clients_deploy(self, test_vars):  # noqa: F811
        """
        Deploys <num_vms> VM clients for vFXT regression testing.
        <num_vms> must be at least 1.
          * the first VM is a STAF server
          * the next (<num_vms> - 1) VMs are STAF clients
        All regression client VMs can run SV.
        """
        log = logging.getLogger("test_reg_clients_deploy")
        atd = test_vars["atd_obj"]

        num_vms = -1  # number of regression VMs (-1 initially, 1 by default)
        if "NUM_REG_VMS" in os.environ:
            num_vms = int(os.environ["NUM_REG_VMS"])
        if "num_reg_vms" in test_vars:
            num_vms = int(test_vars["num_reg_vms"])
        if num_vms < 1:
            if num_vms != -1:  # user set the value incorrectly; enforce min
                log.warning("Number of VMs must be > 0. Setting to 1.")
            num_vms = 1
        log.info("Deploying {} regression VMs".format(num_vms))

        with open(test_vars["ssh_pub_key"], "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        with open("{}/src/client/vmas/azuredeploy.json".format(
                  test_vars["build_root"])) as tfile:
            atd.template = json.load(tfile)

        staf_server_unique_name = atd.deploy_id + "-rc-staf"
        atd.deploy_params = {
            "uniquename": staf_server_unique_name,
            "sshKeyData": ssh_pub_key,
            "virtualNetworkResourceGroup": atd.resource_group,
            "virtualNetworkName": atd.deploy_id + "-vnet",
            "virtualNetworkSubnetName": atd.deploy_id + "-subnet",
            "nfsCommaSeparatedAddresses": ",".join(test_vars["cluster_vs_ips"]),
            "vmCount": 1,
            "nfsExportPath": "/msazure",
            "bootstrapScriptPath": "/bootstrap/bootstrap.reg_client.sh",
            "appEnvironmentVariables": " REG_CLIENT_TYPE=SERVER "
        }

        # The first regression client to be deployed is also a STAF server.
        atd.deploy_name = "deploy_reg_client_1"
        deploy_handle = atd.deploy()

        if ((num_vms - 1) > 0):
            # Remove the first entry of the "resources" section, which is an
            # empty deployment used for tracking purposes. This avoids a
            # collision when attempting to update the empty deployment.
            atd.template["resources"].pop(0)

            log.debug("Deploying {} more regression VM(s)".format(num_vms - 1))
            atd.deploy_params["uniquename"] = atd.deploy_id + "-rc"
            atd.deploy_params["vmCount"] = num_vms - 1
            atd.deploy_params["appEnvironmentVariables"] = " REG_CLIENT_TYPE=CLIENT "
            atd.deploy_name = "deploy_reg_clients_N"
            deploy_result_2 = wait_for_op(atd.deploy())

        # Wait for the result of the first deployment.
        deploy_result_1 = wait_for_op(deploy_handle)

        log.debug("deploy 1 outputs = {}".format(deploy_result_1.properties.outputs))

        log.debug("Get the IP for the first regression client (STAF server).")
        test_vars["staf_server_priv_ip"] = atd.nm_client.network_interfaces.get(
            atd.resource_group,
            "vmnic-" + staf_server_unique_name + "-0",
        ).ip_configurations[0].private_ip_address

        test_vars["staf_client_priv_ips"] = []
        if ((num_vms - 1) > 0):
            log.debug("deploy 2 outputs = {}".format(deploy_result_2.properties.outputs))
            log.debug("Get private IPs for the STAF clients.")
            for i in range(num_vms - 1):
                test_vars["staf_client_priv_ips"].append(
                    atd.nm_client.network_interfaces.get(
                        atd.resource_group,
                        "vmnic-" + atd.deploy_params["uniquename"] + "-" + str(i),
                    ).ip_configurations[0].private_ip_address
                )

    def test_update_reg_clients_hosts(self, test_vars):
        """
        Updates /etc/hosts on the STAF clients so they can contact the STAF
        server.
        """
        log = logging.getLogger("test_update_reg_clients_hosts")
        atd = test_vars["atd_obj"]
        commands = """
            cp /etc/hosts .
            echo ' '                >> hosts
            echo '# STAF server IP' >> hosts
            echo '{0} staf'         >> hosts
            sudo mv hosts /etc/hosts
            echo '#!/bin/bash' > ~/hostdb_entries.sh
            chmod 755 ~/hostdb_entries.sh
            echo "cd ~/Avere-sv" >> ~/hostdb_entries.sh
            echo "source /usr/sv/env/bin/activate" >> ~/hostdb_entries.sh
            echo "export PYTHONPATH=~/Avere-sv:~/Avere-sv/averesv:$PYTHONPATH:$PATH" >> ~/hostdb_entries.sh
            echo "averesv/hostdb.py -a vfxt -m {1} -p '{2}'" >> ~/hostdb_entries.sh
        """.format(
            test_vars["staf_server_priv_ip"],
            test_vars["cluster_mgmt_ip"],
            os.environ["AVERE_ADMIN_PW"]
        ).split("\n")

        # Add hostdb entry calls for each regression client.
        for i, staf_client_ip in enumerate(test_vars["staf_client_priv_ips"]):
            commands.append("echo 'averesv/hostdb.py -L regclient{0} -m {1}' >> ~/hostdb_entries.sh".format(
                i, staf_client_ip))

        # Get the storage account's access key and add that hostdb entry, too.
        sa_key = atd.st_client.storage_accounts.list_keys(
            atd.resource_group, test_vars["storage_account"]).keys[0].value
        commands.append("echo 'averesv/hostdb.py -s URI_TO_AZURE_STORAGE_ACCOUNT -m URI_TO_AZURE_STORAGE_ACCOUNT -M az --cloudCreds \"{0}::{1}\"' >> ~/hostdb_entries.sh".format(test_vars["storage_account"], sa_key))

        last_error = None
        for staf_client_ip in test_vars["staf_client_priv_ips"]:
            for port_attempt in range(1, 11):
                tunnel_local_port = get_unused_local_port()
                with Connection(test_vars["public_ip"],
                                user=test_vars["controller_user"],
                                connect_kwargs={
                                    "key_filename": test_vars["ssh_priv_key"],
                                }).forward_local(local_port=tunnel_local_port,
                                                 remote_port=22,
                                                 remote_host=staf_client_ip):
                    node_c = Connection("127.0.0.1",
                                        user=test_vars["controller_user"],
                                        port=tunnel_local_port,
                                        connect_kwargs={
                                            "key_filename": test_vars["ssh_priv_key"],
                                        })
                    try:
                        node_c.open()

                        # If port_attempt > 1, last_error had the exception
                        # from the last iteration. Clear it.
                        last_error = None
                    except NoValidConnectionsError as ex:
                        last_error = ex
                        exp_err = "Unable to connect to port {} on 127.0.0.1".format(tunnel_local_port)
                        if exp_err not in str(ex):
                            raise
                        else:
                            log.warning("{0} (attempt #{1}, retrying)".format(
                                        exp_err, str(port_attempt)))
                            continue  # iterate

                    run_ssh_commands(node_c.client, commands)

                    # Copy SSH keys to the client.
                    scp_cli = SCPClient(node_c.transport)
                    scp_cli.put(test_vars["ssh_priv_key"], "~/.ssh/id_rsa")
                    scp_cli.put(test_vars["ssh_pub_key"], "~/.ssh/id_rsa.pub")
                    scp_cli.close()
                log.debug("Connection to {} closed".format(staf_client_ip))
                break  # no need to iterate again

            if last_error:
                log.error("See previous error(s) above. Raising last exception.")
                raise last_error


if __name__ == "__main__":
    pytest.main(sys.argv)
