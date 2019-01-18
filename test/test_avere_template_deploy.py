#!/usr/bin/python3

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

import json
import logging
import os
from time import sleep, time

import pytest

from lib.helpers import run_averecmd, run_ssh_commands, wait_for_op
from lib.pytest_fixtures import (averecmd_params, mnt_nodes,  # noqa: F401
                                 resource_group, scp_cli, ssh_con, test_vars,
                                 vs_ips)


class TestDeployment:
    def test_deploy_template(self, resource_group, test_vars):  # noqa: F811
        log = logging.getLogger("test_deploy_template")
        td = test_vars["atd_obj"]
        with open("{}/src/vfxt/azuredeploy-auto.json".format(
                  os.environ["BUILD_SOURCESDIRECTORY"])) as tfile:
            td.template = json.load(tfile)
        with open(os.path.expanduser(r"~/.ssh/id_rsa.pub"), "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        td.deploy_params = {
            "avereClusterName": td.deploy_id + "-cluster",
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
        test_vars["controller_name"] = td.deploy_params["controllerName"]
        test_vars["controller_user"] = td.deploy_params["controllerAdminUsername"]

        log.debug("Generated deploy parameters: \n{}".format(
                  json.dumps(td.deploy_params, indent=4)))
        td.deploy_name = "test_deploy_template"
        try:
            deploy_result = wait_for_op(td.deploy())
            test_vars["deploy_outputs"] = deploy_result.properties.outputs
        finally:
            test_vars["controller_ip"] = td.nm_client.public_ip_addresses.get(
                td.resource_group, "publicip-" + test_vars["controller_name"]
            ).ip_address

    def test_basic_fileops(self, mnt_nodes, scp_cli, ssh_con):  # noqa: F811
        script_name = "check_node_basic_fileops.sh"
        scp_cli.put("{0}/test/{1}".format(
                       os.environ["BUILD_SOURCESDIRECTORY"], script_name),
                    r"~/.")
        commands = """
            chmod +x {0}
            ./{0}
            """.format(script_name).split("\n")
        run_ssh_commands(ssh_con, commands)

    def test_node_health(self, averecmd_params):  # noqa: F811
        for node in run_averecmd(**averecmd_params, method='node.list'):
            result = run_averecmd(**averecmd_params, method='node.get',
                                  args=node)
            assert(result[node]['state'] == 'up')

    def test_ha_enabled(self, averecmd_params):  # noqa: F811
        result = run_averecmd(**averecmd_params, method='cluster.get')
        assert(result['ha'] == 'enabled')

    def test_ping_nodes(self, ssh_con, vs_ips):  # noqa: F811
        commands = []
        for vs_ip in vs_ips:
            commands.append("ping -c 3 {}".format(vs_ip))
        run_ssh_commands(ssh_con, commands)

    def test_for_cores(self, averecmd_params):  # noqa: F811
        log = logging.getLogger("test_for_cores")
        node_cores = run_averecmd(**averecmd_params,
                                  method='support.listCores',
                                  args='cluster')
        cores_found = False
        for cores in node_cores.values():
            if len(cores):
                cores_found = True
                break

        if not cores_found:
            return  # success

        log.error("Cores found: {}".format(node_cores))

        # collect and upload a "normal" GSI bundle
        assert('success' == run_averecmd(**averecmd_params,
                                         method='support.acceptTerms',
                                         args='yes'))
        if not run_averecmd(**averecmd_params, method='support.testUpload'):
            log.warning("GSI test upload failed. Proceeding anyway.")

        log.info("Starting normal GSI collection/upload")
        job_id = run_averecmd(**averecmd_params,
                              method='support.executeNormalMode',
                              args='cluster gsimin')
        log.debug("GSI upload job ID: {}".format(job_id))

        timeout_secs = 60 * 10
        time_start = time()
        time_end = time_start + timeout_secs
        gsi_upload_done = False
        while not gsi_upload_done and time() < time_end:
            gsi_upload_done = run_averecmd(**averecmd_params,
                                           method='support.taskIsDone',
                                           args=job_id)
            log.info(">> GSI collection/upload in progress ({} sec)".format(
                     int(time() - time_start)))
            sleep(10)

        if not gsi_upload_done:
            log.error("GSI upload did not complete after {} seconds".format(
                      timeout_secs))
            assert(gsi_upload_done)
        else:
            log.info("GSI upload complete")

        assert(not cores_found)


if __name__ == "__main__":
    pytest.main()
