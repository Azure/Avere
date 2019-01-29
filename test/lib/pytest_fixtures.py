# standard imports
import json
import logging
import os

# from requirements.txt
import pytest
from arm_template_deploy import ArmTemplateDeploy
from scp import SCPClient

# local libraries
from lib.helpers import (create_ssh_client, run_ssh_command, run_ssh_commands)


@pytest.fixture()
def averecmd_params(ssh_con, test_vars):
    return {
        "ssh_client": ssh_con,
        "password": os.environ["AVERE_ADMIN_PW"],
        "node_ip": test_vars["cluster_mgmt_ip"]
    }


@pytest.fixture()
def mnt_nodes(ssh_con, test_vars):
    check = run_ssh_command(ssh_con, "ls ~/STATUS.NODES_MOUNTED",
                            ignore_nonzero_rc=True)
    if check['rc']:  # nodes were not already mounted
        commands = """
            sudo apt-get update
            sudo apt-get install nfs-common
            """.split("\n")
        for i, vs_ip in enumerate(test_vars["cluster_vs_ips"]):
            commands.append("sudo mkdir -p /nfs/node{}".format(i))
            commands.append("sudo chown nobody:nogroup /nfs/node{}".format(i))
            fstab_line = "{}:/msazure /nfs/node{} nfs ".format(vs_ip, i) + \
                         "hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0"
            commands.append("sudo sh -c 'echo \"{}\" >> /etc/fstab'".format(
                            fstab_line))
        commands.append("sudo mount -a")
        commands.append("touch ~/STATUS.NODES_MOUNTED")
        run_ssh_commands(ssh_con, commands)


@pytest.fixture()
def resource_group(test_vars):
    log = logging.getLogger("resource_group")
    rg = test_vars["atd_obj"].create_resource_group()
    log.info("Created Resource Group: {}".format(rg))
    return rg


@pytest.fixture()
def storage_account(test_vars):
    log = logging.getLogger("storage_account")
    atd = test_vars["atd_obj"]
    storage_account = atd.st_client.storage_accounts.get_properties(
        atd.resource_group,
        atd.deploy_id + "sa"
    )
    log.info("Linked Storage Account: {}".format(storage_account))
    return storage_account

@pytest.fixture()
def scp_cli(ssh_con):
    client = SCPClient(ssh_con.get_transport())
    yield client
    client.close()


@pytest.fixture()
def ssh_con(test_vars):
    client = create_ssh_client(test_vars["controller_user"],
                               test_vars["controller_ip"])
    yield client
    client.close()


@pytest.fixture(scope="module")
def test_vars():
    """
    Loads saved test variables, instantiates an ArmTemplateDeploy object, and
    dumps test variables during teardown.
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
