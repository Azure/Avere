# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

# standard imports
import json
import logging
import os

# from requirements.txt
import pytest
from fabric import Connection
from scp import SCPClient

# local libraries
from arm_template_deploy import ArmTemplateDeploy
from lib.helpers import (get_unused_local_port, run_ssh_command,
                         run_ssh_commands, wait_for_op)


# COMMAND-LINE OPTIONS ########################################################
def pytest_addoption(parser):
    def envar_check(envar):
        if envar in os.environ:
            return os.environ[envar]
        return None

    parser.addoption(
        "--build_root", action="store",
        default=envar_check("BUILD_SOURCESDIRECTORY"),
        help="Local path to the root of the Azure/Avere repo clone "
        + "(e.g., /home/user1/git/Azure/Avere). This is used to find the "
        + "various templates that are deployed during these tests. (default: "
        + "$BUILD_SOURCESDIRECTORY if set, else current directory)",
    )
    parser.addoption(
        "--location", action="store", default="westus2",
        help="Azure region short name to use for deployments (default: westus2)",
    )
    parser.addoption(
        "--prefer_cli_args", action="store_true",
        default=False,
        help="When specified, prioritize custom command-line arguments over "
        + "the values in the file pointed to by \"test_vars_file\".",
    )
    parser.addoption(
        "--ssh_priv_key", action="store",
        default=os.path.expanduser(r"~/.ssh/id_rsa"),
        help="SSH private key to use in deployments and tests (default: ~/.ssh/id_rsa)",
    )
    parser.addoption(
        "--ssh_pub_key", action="store",
        default=os.path.expanduser(r"~/.ssh/id_rsa.pub"),
        help="SSH public key to use in deployments and tests (default: ~/.ssh/id_rsa.pub)",
    )
    parser.addoption(
        "--test_vars_file", action="store",
        default=envar_check("VFXT_TEST_VARS_FILE"),
        help="Test variables file used for passing values between runs. This "
        + "file is in JSON format. It is loaded during test setup and written "
        + "out during test teardown. The contents of this file override other "
        + "custom command-line options unless the \"prefer_cli_args\" option "
        + "is specified. (default: $VFXT_TEST_VARS_FILE if set, else None)"
    )


# FIXTURES ####################################################################
@pytest.fixture()
def averecmd_params(ssh_con, test_vars):
    return {
        "ssh_client": ssh_con,
        "password": os.environ["AVERE_ADMIN_PW"],
        "node_ip": test_vars["cluster_mgmt_ip"]
    }


@pytest.fixture()
def mnt_nodes(ssh_con, test_vars):
    if ("storage_account" not in test_vars) or (not test_vars["storage_account"]):
        return

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


@pytest.fixture(scope="module")
def resource_group(test_vars):
    log = logging.getLogger("resource_group")
    rg = test_vars["atd_obj"].create_resource_group()
    log.info("Resource Group: {}".format(rg))
    return rg


@pytest.fixture(scope="module")
def storage_account(test_vars):
    log = logging.getLogger("storage_account")
    atd = test_vars["atd_obj"]
    sa = atd.st_client.storage_accounts.get_properties(
        atd.resource_group,
        atd.storage_account
    )
    log.info("Storage Account: {}".format(sa))
    return sa


@pytest.fixture()
def scp_con(ssh_con_fabric):
    """Create an SCP client based on an SSH connection to the controller."""
    log = logging.getLogger("scp_con")
    # client = SCPClient(ssh_con.get_transport())  # PARAMIKO
    client = SCPClient(ssh_con_fabric.transport)
    yield client
    log.debug("Closing SCP client.")
    client.close()


@pytest.fixture()
def ssh_con(ssh_con_fabric):
    return ssh_con_fabric.client


@pytest.fixture()
def ssh_con_fabric(test_vars):
    """Create an SSH connection to the controller."""
    log = logging.getLogger("ssh_con_fabric")

    # SSH connection/client to the public IP.
    pub_client = Connection(test_vars["public_ip"],
                            user=test_vars["controller_user"],
                            connect_kwargs={
                                "key_filename": test_vars["ssh_priv_key"],
                            })

    # If the controller's IP is not the same as the public IP, then we are
    # using a jumpbox to get into the VNET containing the controller. In that
    # case, create an SSH tunnel before connecting to the controller.
    msg_con = "SSH connection to controller ({})".format(test_vars["controller_ip"])
    if test_vars["public_ip"] != test_vars["controller_ip"]:
        tunnel_local_port = get_unused_local_port()
        tunnel_remote_port = 22

        msg_con += " via jumpbox ({0}), local port {1}".format(
            test_vars["public_ip"], tunnel_local_port)

        log.debug("Opening {}".format(msg_con))
        with pub_client.forward_local(local_port=tunnel_local_port,
                                      remote_port=tunnel_remote_port,
                                      remote_host=test_vars["controller_ip"]):
            client = Connection("127.0.0.1",
                                user=test_vars["controller_user"],
                                port=tunnel_local_port,
                                connect_kwargs={
                                    "key_filename": test_vars["ssh_priv_key"],
                                })
            client.open()
            yield client
        log.debug("{} closed".format(msg_con))
    else:
        log.debug("Opening {}".format(msg_con))
        pub_client.open()
        yield pub_client
        log.debug("Closing {}".format(msg_con))

    pub_client.close()


@pytest.fixture(scope="module")
def test_vars(request):
    """
    Loads saved test variables, instantiates an ArmTemplateDeploy object, and
    dumps test variables during teardown.
    """
    log = logging.getLogger("test_vars")

    # Load command-line arguments into a dictionary.
    build_root = request.config.getoption("--build_root")
    if not build_root:
        build_root = os.getcwd()

    test_vars_file = request.config.getoption("--test_vars_file")
    cl_opts = {
        "build_root": build_root,
        "location": request.config.getoption("--location"),
        "ssh_priv_key": request.config.getoption("--ssh_priv_key"),
        "ssh_pub_key": request.config.getoption("--ssh_pub_key"),
        "test_vars_file": test_vars_file
    }
    cja = {"sort_keys": True, "indent": 4}  # common JSON arguments
    log.debug("JSON from command-line args: {}".format(
              json.dumps(cl_opts, **cja)))

    vars = {**cl_opts}  # prime vars with cl_opts

    # Load JSON from test_vars_file, if specified.
    if test_vars_file and os.path.isfile(test_vars_file):
        log.debug("Loading into vars from {} (test_vars_file)".format(
                  test_vars_file))
        with open(test_vars_file, "r") as vtvf:
            vars = {**vars, **json.load(vtvf)}
        log.debug("After loading from test_vars_file, vars is : {}".format(
                json.dumps(vars, **cja)))

    # Override test_vars_file values with command-line arguments.
    if request.config.getoption("--prefer_cli_args"):
        vars = {**vars, **cl_opts}
        log.debug("Overwrote vars with command-line args: {}".format(
              json.dumps(vars, **cja)))

    atd_obj = ArmTemplateDeploy(_fields={**vars})
    # "Promote" serializable members to the top level.
    vars = {**vars, **json.loads(atd_obj.serialize())}

    if test_vars_file:  # write out vars to test_vars_file
        log.debug("vars: {}".format(json.dumps(vars, **cja)))
        log.debug("Saving vars to {} (test_vars_file)".format(test_vars_file))
        with open(test_vars_file, "w") as vtvf:
            json.dump(vars, vtvf, **cja)

    vars["atd_obj"] = atd_obj  # store the object in a common place

    yield vars

    if test_vars_file:  # write out vars to test_vars_file
        vars = {**vars, **json.loads(vars["atd_obj"].serialize())}
        vars.pop("atd_obj")
        log.debug("vars: {}".format(json.dumps(vars, **cja)))
        log.debug("Saving vars to {} (test_vars_file)".format(test_vars_file))
        with open(test_vars_file, "w") as vtvf:
            json.dump(vars, vtvf, **cja)


@pytest.fixture()
def ext_vnet(test_vars):
    """
    Creates a resource group containing a new VNET, subnet, public IP, and
    jumpbox for use in other tests.
    """
    log = logging.getLogger("ext_vnet")
    vnet_atd = ArmTemplateDeploy(
        location=test_vars["location"],
        resource_group=test_vars["atd_obj"].deploy_id + "-rg-vnet"
    )
    rg = vnet_atd.create_resource_group()
    log.info("Resource Group: {}".format(rg))

    vnet_atd.deploy_name = "ext_vnet"
    with open("{}/src/vfxt/azuredeploy.vnet.json".format(
                test_vars["build_root"])) as tfile:
        vnet_atd.template = json.load(tfile)

    with open(test_vars["ssh_pub_key"], "r") as ssh_pub_f:
        ssh_pub_key = ssh_pub_f.read()

    vnet_atd.deploy_params = {
        "uniqueName": test_vars["atd_obj"].deploy_id,
        "jumpboxAdminUsername": "azureuser",
        "jumpboxSSHKeyData": ssh_pub_key
    }
    test_vars["ext_vnet"] = wait_for_op(vnet_atd.deploy()).properties.outputs
    log.debug(test_vars["ext_vnet"])
    return test_vars["ext_vnet"]
