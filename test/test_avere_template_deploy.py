#!/usr/bin/python3

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

import json
import logging
import os

import pytest

from lib import helpers
from lib.pytest_fixtures import (group_vars, scp_client, ssh_client,
                                 vserver_ip_list)


# TEST CASES ##################################################################
class TestDeployment:
    def test_deploy_template(self, group_vars):
        log = logging.getLogger("test_deploy_template")
        td = group_vars["atd_obj"]
        with open("{}/src/vfxt/azuredeploy-auto.json".format(
                  os.environ["BUILD_SOURCESDIRECTORY"])) as tfile:
            td.template = json.load(tfile)
        with open(os.path.expanduser(r"~/.ssh/id_rsa.pub"), "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        td.deploy_params = {
            "virtualNetworkResourceGroup": td.resource_group,
            "virtualNetworkName": td.deploy_id + "-vnet",
            "virtualNetworkSubnetName": td.deploy_id + "-subnet",
            "avereBackedStorageAccountName": td.deploy_id + "sa",
            "controllerName": td.deploy_id + "-con",
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerSSHKeyData": ssh_pub_key,
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
        }
        group_vars["controller_name"] = td.deploy_params["controllerName"]
        group_vars["controller_user"] = td.deploy_params["controllerAdminUsername"]

        log.debug("Generated deploy parameters: \n{}".format(
                  json.dumps(td.deploy_params, indent=4)))
        td.deploy_name = "test_deploy_template"
        try:
            deploy_result = helpers.wait_for_op(td.deploy())
            group_vars["deploy_outputs"] = deploy_result.properties.outputs
        finally:
            group_vars["controller_ip"] = td.nm_client.public_ip_addresses.get(
                td.resource_group, "publicip-" + group_vars["controller_name"]
            ).ip_address

    def test_get_vfxt_log(self, group_vars, scp_client):
        log = logging.getLogger("test_get_vfxt_log")
        log.info("Getting vfxt.log from controller: {}".format(
            group_vars["controller_name"]))
        scp_client.get(r"~/vfxt.log",
                       r"./vfxt." + group_vars["controller_name"] + ".log")

    def test_mount_nodes_on_controller(self, vserver_ip_list, ssh_client):
        commands = """
            sudo apt-get update
            sudo apt-get install nfs-common
            """.split("\n")

        for i, vs_ip in enumerate(vserver_ip_list):
            commands.append("sudo mkdir -p /nfs/node{}".format(i))
            commands.append("sudo chown nobody:nogroup /nfs/node{}".format(i))
            fstab_line = "{}:/msazure /nfs/node{} nfs ".format(vs_ip, i) + \
                         "hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0"
            commands.append("sudo sh -c 'echo \"{}\" >> /etc/fstab'".format(
                            fstab_line))

        commands.append("sudo mount -a")
        helpers.run_ssh_commands(ssh_client, commands)

    def test_ping_nodes(self, vserver_ip_list, ssh_client):
        commands = []
        for vs_ip in vserver_ip_list:
            commands.append("ping -c 3 {}".format(vs_ip))
        helpers.run_ssh_commands(ssh_client, commands)

    def test_node_basic_fileops(self, group_vars, ssh_client, scp_client):
        script_name = "check_node_basic_fileops.sh"
        scp_client.put("{0}/test/{1}".format(
                       os.environ["BUILD_SOURCESDIRECTORY"], script_name),
                       r"~/.")
        commands = """
            chmod +x {0}
            ./{0}
            """.format(script_name).split("\n")
        helpers.run_ssh_commands(ssh_client, commands)


if __name__ == "__main__":
    pytest.main()
