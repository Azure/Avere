import json
import logging
import os

import pytest
from scp import SCPClient

from arm_template_deploy import ArmTemplateDeploy
from lib import helpers


@pytest.fixture()
def averecmd_params(ssh_con, test_vars, vs_ips):
    return {
        "ssh_client": ssh_con,
        "password": test_vars["atd_obj"].deploy_params["adminPassword"],
        "node_ip": vs_ips[0]
    }


@pytest.fixture()
def mnt_nodes(ssh_con, vs_ips):
    check = helpers.run_ssh_command(ssh_con, "ls ~/STATUS.NODES_MOUNTED",
                                    ignore_nonzero_rc=True)
    if check['rc']:  # nodes were not already mounted
        commands = """
            sudo apt-get update
            sudo apt-get install nfs-common
            """.split("\n")
        for i, vs_ip in enumerate(vs_ips):
            commands.append("sudo mkdir -p /nfs/node{}".format(i))
            commands.append("sudo chown nobody:nogroup /nfs/node{}".format(i))
            fstab_line = "{}:/msazure /nfs/node{} nfs ".format(vs_ip, i) + \
                         "hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0"
            commands.append("sudo sh -c 'echo \"{}\" >> /etc/fstab'".format(
                            fstab_line))
        commands.append("sudo mount -a")
        commands.append("touch ~/STATUS.NODES_MOUNTED")
        helpers.run_ssh_commands(ssh_con, commands)


@pytest.fixture()
def resource_group(test_vars):
    log = logging.getLogger("resource_group")
    rg = test_vars["atd_obj"].create_resource_group()
    log.info("Created Resource Group: {}".format(rg))
    return rg


@pytest.fixture()
def storage_account(test_vars):
    log = logging.getLogger("storage_account")
    storage_account = helpers.wait_for_op(test_vars["atd_obj"].create_storage_account())
    log.info("Created Storage Account: {}".format(storage_account))
    return storage_account


@pytest.fixture()
def event_hub(test_vars):
    log = logging.getLogger("event_hub")
    event_hub = test_vars["atd_obj"].create_event_hub()
    log.info("Created Event Hub : {}".format(event_hub))


@pytest.fixture()
def scp_cli(ssh_con):
    client = SCPClient(ssh_con.get_transport())
    yield client
    client.close()


@pytest.fixture()
def ssh_con(test_vars):
    client = helpers.create_ssh_client(test_vars["controller_user"],
                                       test_vars["controller_ip"])
    yield client
    client.close()


@pytest.fixture(scope="module")
def test_vars():
    """
    Instantiates an ArmTemplateDeploy object, creates the resource group as
    test-group setup, and deletes the resource group as test-group teardown.
    """
    log = logging.getLogger("test_vars")
    vars = {}
    if "VFXT_TEST_VARS_FILE" in os.environ and \
       os.path.isfile(os.environ["VFXT_TEST_VARS_FILE"]):
        log.debug("Loading into vars from {} (VFXT_TEST_VARS_FILE)".format(
                  os.environ["VFXT_TEST_VARS_FILE"]))
        with open(os.environ["VFXT_TEST_VARS_FILE"], "r") as vtvf:
            vars = {**vars, **json.load(vtvf)}
    log.debug("Loaded the following JSON into vars: {}".format(
              json.dumps(vars, sort_keys=True, indent=4)))

    vars["atd_obj"] = ArmTemplateDeploy(_fields=vars.pop("atd_obj", {}))

    yield vars

    if "VFXT_TEST_VARS_FILE" in os.environ:
        vars["atd_obj"] = json.loads(vars["atd_obj"].serialize())
        log.debug("vars: {}".format(json.dumps(vars, sort_keys=True, indent=4)))
        log.debug("Saving vars to {} (VFXT_TEST_VARS_FILE)".format(
                  os.environ["VFXT_TEST_VARS_FILE"]))
        with open(os.environ["VFXT_TEST_VARS_FILE"], "w") as vtvf:
            json.dump(vars, vtvf)


@pytest.fixture()
def vs_ips(test_vars):
    if "vs_ips" not in test_vars:
        vserver_ips = test_vars["deploy_outputs"]["vserver_ips"]["value"]
        test_vars["vs_ips"] = helpers.split_ip_range(vserver_ips)
    return test_vars["vs_ips"]
