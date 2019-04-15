# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

# standard imports
import json
import logging
import os

# from requirements.txt
import pytest
from fabric import Connection
from paramiko.ssh_exception import NoValidConnectionsError
from scp import SCPClient

# local libraries
from arm_template_deploy import ArmTemplateDeploy
from lib.helpers import (get_unused_local_port, run_ssh_command,
                         run_ssh_commands, wait_for_op)


# COMMAND-LINE OPTIONS ########################################################
def pytest_addoption(parser):
    parser.addoption(
        "--build_root", action="store", default=None,
        help="Local path to the root of the Azure/Avere repo clone "
        + "(e.g., /home/user1/git/Azure/Avere). This is used to find the "
        + "various templates that are deployed during these tests. (default: "
        + "$BUILD_SOURCESDIRECTORY if set, else current directory)",
    )
    parser.addoption(
        "--location", action="store", default=None,
        help="Azure region short name to use for deployments (default: westus2)",
    )
    parser.addoption(
        "--ssh_priv_key", action="store", default=None,
        help="SSH private key to use in deployments and tests (default: ~/.ssh/id_rsa)",
    )
    parser.addoption(
        "--ssh_pub_key", action="store", default=None,
        help="SSH public key to use in deployments and tests (default: ~/.ssh/id_rsa.pub)",
    )
    parser.addoption(
        "--test_vars_file", action="store", default=None,
        help="Test variables file used for passing values between runs. This "
        + "file is in JSON format. It is loaded during test setup and written "
        + "out during test teardown. Command-line options override variables "
        + "in this file. (default: $VFXT_TEST_VARS_FILE if set, else None)"
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

    log = logging.getLogger("mnt_nodes")
    check = run_ssh_command(ssh_con, "ls ~/STATUS.NODES_MOUNTED",
                            ignore_nonzero_rc=True, timeout=30)
    if check['rc']:  # nodes were not already mounted
        # Update needed packages.
        commands = ["sudo apt-get update", "sudo apt-get install nfs-common"]
        run_ssh_commands(ssh_con, commands, timeout=600)

        # Set up mount points and /etc/fstab.
        commands = []
        for i, vs_ip in enumerate(test_vars["cluster_vs_ips"]):
            commands.append("sudo mkdir -p /nfs/node{}".format(i))
            commands.append("sudo chown nobody:nogroup /nfs/node{}".format(i))
            fstab_line = "{}:/msazure /nfs/node{} nfs ".format(vs_ip, i) + \
                         "hard,nointr,proto=tcp,mountproto=tcp,retry=5 0 0"
            commands.append("sudo sh -c 'echo \"{}\" >> /etc/fstab'".format(
                            fstab_line))
        run_ssh_commands(ssh_con, commands, timeout=30)

        # Mount the nodes.
        def _log_diag(in_str):
            log.info(json.dumps(in_str, indent=4).replace("\\n", "\n"))
        try:
            commands = """
                sudo service portmap restart
                sleep 3
                sudo mount -av
                touch ~/STATUS.NODES_MOUNTED
            """.split("\n")
            _log_diag(run_ssh_commands(ssh_con, commands, timeout=300))
        except Exception as e:
            # Show some diag info.
            log.info("Exception caught when attempting to mount. Diag info:")
            diag_commands = """
                cat /etc/mtab
                nfsstat
                sudo ufw status
                service portmap status
                sudo iptables -L
            """.split("\n")
            _log_diag(run_ssh_commands(ssh_con, diag_commands, ignore_nonzero_rc=True))
            for vs_ip in test_vars["cluster_vs_ips"]:
                _log_diag(run_ssh_command(ssh_con, "rpcinfo -p " + vs_ip, ignore_nonzero_rc=True))
            raise


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
        for port_attempt in range(1, 11):
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
                try:
                    client.open()
                except NoValidConnectionsError as ex:
                    exp_err = "Unable to connect to port {} on 127.0.0.1".format(tunnel_local_port)
                    if exp_err not in str(ex):
                        raise
                    else:
                        log.warning("{0} (attempt #{1}, retrying)".format(
                                    exp_err, str(port_attempt)))
                        continue

                yield client
            log.debug("{} closed".format(msg_con))
            break  # no need to iterate again
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

    def envar_check(envar):
        if envar in os.environ:
            return os.environ[envar]
        return None

    # Load command-line arguments into a dictionary.
    cl_opts = {
        "build_root": request.config.getoption("--build_root"),
        "location": request.config.getoption("--location"),
        "ssh_priv_key": request.config.getoption("--ssh_priv_key"),
        "ssh_pub_key": request.config.getoption("--ssh_pub_key"),
        "test_vars_file": request.config.getoption("--test_vars_file")
    }
    cja = {"sort_keys": True, "indent": 4}  # common JSON arguments
    log.debug("JSON from command-line args: {}".format(
              json.dumps(cl_opts, **cja)))

    # Set build_root value (command-line arg, envar, cwd).
    build_root = request.config.getoption("--build_root")
    if not build_root:
        build_root = envar_check("BUILD_SOURCESDIRECTORY")
    if not build_root:
        build_root = os.getcwd()
    log.debug("build_root = {}".format(build_root))

    # Set test_vars_file value (command-line arg, envar).
    test_vars_file = request.config.getoption("--test_vars_file")
    if not test_vars_file:
        test_vars_file = envar_check("VFXT_TEST_VARS_FILE")
    log.debug("test_vars_file = {}".format(test_vars_file))

    default_cl_opts = {  # defaults for command-line options
        "build_root": build_root,
        "location": "westus2",
        "ssh_priv_key": os.path.expanduser(r"~/.ssh/id_rsa"),
        "ssh_pub_key": os.path.expanduser(r"~/.ssh/id_rsa.pub"),
        "test_vars_file": test_vars_file
    }
    log.debug("Defaults for command-line args: {}".format(
              json.dumps(default_cl_opts, **cja)))

    vars = {}

    # Load JSON from test_vars_file, if specified.
    if test_vars_file and os.path.isfile(test_vars_file):
        log.debug("Loading into vars from {} (test_vars_file)".format(
                  test_vars_file))
        with open(test_vars_file, "r") as vtvf:
            vars = {**vars, **json.load(vtvf)}
        log.debug("After loading from test_vars_file, vars is: {}".format(
                json.dumps(vars, **cja)))

    # Override test_vars_file values with command-line arguments.
    for k, v in cl_opts.items():
        if v:  # specified on the command-line, so override
            vars[k] = v
        elif k not in vars:  # not specified on command-line nor test vars file
            vars[k] = default_cl_opts[k]  # use the default
    log.debug("After overriding with command-line args, vars is: {}".format(
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
