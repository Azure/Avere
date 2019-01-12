#!/usr/bin/python3

"""
Driver for testing template-based deployment of the Avere vFXT product.
"""

import json
import logging
import os
from time import sleep, time

import paramiko
import pytest
from scp import SCPClient

from avere_template_deploy import AvereTemplateDeploy
from sshtunnel import SSHTunnelForwarder


# TEST CASES ##################################################################
class TestDeployment:

    def test_deploy_template(self, group_vars):
        log = logging.getLogger('test_deploy_template')
        atd = group_vars['atd']
        with open(os.environ['BUILD_SOURCESDIRECTORY'] + '/src/vfxt/azuredeploy-auto.json') as tfile:
            atd.template = json.load(tfile)
        with open(os.path.expanduser(r'~/.ssh/id_rsa.pub'), 'r') as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        atd.deploy_params = {
            'virtualNetworkResourceGroup': atd.resource_group,
            'virtualNetworkName': atd.deploy_id + '-vnet',
            'virtualNetworkSubnetName': atd.deploy_id + '-subnet',
            'avereBackedStorageAccountName': atd.deploy_id + 'sa',
            'controllerName': atd.deploy_id + '-con',
            'controllerAdminUsername': 'azureuser',
            'controllerAuthenticationType': 'sshPublicKey',
            'controllerSSHKeyData': ssh_pub_key,
            'adminPassword': os.environ['AVERE_ADMIN_PW'],
            'controllerPassword': os.environ['AVERE_CONTROLLER_PW']
        }
        group_vars['controller_name'] = atd.deploy_params['controllerName']
        group_vars['controller_user'] = atd.deploy_params['controllerAdminUsername']

        log.debug('Generated deploy parameters: \n{}'.format(
            json.dumps(atd.deploy_params, indent=4)))
        atd.deploy_name = 'test_deploy_template'
        try:
            group_vars['deploy_result'] = wait_for_op(atd.deploy())
        finally:
            group_vars['controller_ip'] = atd.nm_client.public_ip_addresses.get(
                atd.resource_group,
                'publicip-' + group_vars['controller_name']).ip_address

    def test_get_vfxt_log(self, group_vars, scp_client):
        log = logging.getLogger('test_get_vfxt_log')
        log.info('Getting vfxt.log from controller: {}'.format(
            group_vars['controller_name']))
        scp_client.get(r'~/vfxt.log',
                       r'./vfxt.' + group_vars['controller_name'] + '.log')

    def test_vdbench_setup(self, group_vars, ssh_client):
        with open(os.path.expanduser(r'~/.ssh/id_rsa.pub'), 'r') as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        group_vars['ssh_pub_key'] = ssh_pub_key
        result = group_vars['deploy_result']
        vserver_ips = result.properties.outputs["vserveR_IPS"]["value"]
        x = vserver_ips.split("-")
        ip1 = x[0]
        ip2 = x[1]

        ip1_split = ip1.split(".")
        ip_low = ip1_split[-1]
        ip_hi = ip2.split(".")[-1]

        ip_prefix = ".".join(ip1_split[:-1]) + "."
        vserver_list = [ip_prefix + str(n) for n in range(int(ip_low), int(ip_hi)+1)]
        group_vars['vserver_list'] = vserver_list
        commands = """
            sudo apt-get update
            sudo apt-get install nfs-common
            """.split('\n')
        for i, vs_ip in enumerate(vserver_list):
            commands.append('sudo mkdir -p /nfs/node{}'.format(i))
            commands.append('sudo chown nobody:nogroup /nfs/node{}'.format(i))

            fstab_line = vs_ip + ":/msazure /nfs/node" + str(i) + " nfs " + \
                "hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0"

            echo_str = 'sudo sh -c \'echo "' + fstab_line + '" >> /etc/fstab\''
            commands.append(echo_str)
        commands = commands + """
            sudo mount -a
            sudo mkdir -p /nfs/node0/bootstrap
            cd /nfs/node0/bootstrap
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.vdbench.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/bootstrap.vdbench.sh
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/vdbench50407.zip https://avereimageswestus.blob.core.windows.net/vdbench/vdbench50407.zip
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/vdbenchVerify.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/vdbenchVerify.sh
            sudo chmod +x /nfs/node0/bootstrap/vdbenchVerify.sh
            /nfs/node0/bootstrap/vdbenchVerify.sh
            """.split('\n')
        run_ssh_commands(ssh_client, commands)

    def test_ping_nodes(self, group_vars, ssh_client):
        commands = []
        for vs_ip in group_vars['vserver_list']:
            commands.append('ping -c 3 {}'.format(vs_ip))
        run_ssh_commands(ssh_client, commands)

    def test_node_basic_fileops(self, group_vars, ssh_client, scp_client):
        script_name = 'check_node_basic_fileops.sh'
        scp_client.put('{0}/test/{1}'.format(
                       os.environ['BUILD_SOURCESDIRECTORY'], script_name),
                       r'~/.')
        commands = """
            chmod +x {0}
            ./{0}
            """.format(script_name).split('\n')
        run_ssh_commands(ssh_client, commands)

    def test_vdbench_deploy(self, group_vars):
        atd = group_vars['atd']
        ssh_pub_key = group_vars['ssh_pub_key']
        with open('{}/src/client/vmas/azuredeploy.json'.format(
                  os.environ['BUILD_SOURCESDIRECTORY'])) as tfile:
            atd.template = json.load(tfile)
        orig_params = atd.deploy_params.copy()
        atd.deploy_params = {
            'uniquename': atd.deploy_id,
            'sshKeyData': ssh_pub_key,
            'virtualNetworkResourceGroup': orig_params['virtualNetworkResourceGroup'],
            'virtualNetworkName': orig_params['virtualNetworkName'],
            'virtualNetworkSubnetName': orig_params['virtualNetworkSubnetName'],
            'nfsCommaSeparatedAddresses': ','.join(group_vars['vserver_list']),
            'vmCount': 12,
            'nfsExportPath': '/msazure',
            'bootstrapScriptPath': '/bootstrap/bootstrap.vdbench.sh'
        }
        atd.deploy_name = 'test_vdbench'
        group_vars['deploy_vd_result'] = wait_for_op(atd.deploy())

    def test_vdbench_template_run(self, group_vars):
        result_vd = group_vars['deploy_vd_result']
        node_ip = result_vd.properties.outputs["nodE_0_IP_ADDRESS"]["value"]
        with SSHTunnelForwarder(
            group_vars['controller_ip'],
            ssh_username=group_vars['controller_user'],
            ssh_pkey=os.path.expanduser(r'~/.ssh/id_rsa'),
            remote_bind_address=(node_ip, 22)
        ) as ssh_tunnel:
            sleep(1)
            try:
                ssh_client = create_ssh_client(group_vars['controller_user'],
                                               '127.0.0.1',
                                               ssh_tunnel.local_bind_port)
                scp_client = SCPClient(ssh_client.get_transport())
                try:
                    scp_client.put(os.path.expanduser(r'~/.ssh/id_rsa'),
                                   r'~/.ssh/id_rsa')
                finally:
                    scp_client.close()
                commands = """~/copy_idrsa.sh
                    cd
                """.split('\n')
                # ./run_vdbench.sh inmem.conf uniquestring1  # TODO: reenable
                run_ssh_commands(ssh_client, commands)
            finally:
                ssh_client.close()


# FIXTURES ####################################################################
@pytest.fixture(scope='class')
def group_vars():
    """
    Instantiates an AvereTemplateDeploy object, creates the resource group as
    test-group setup, and deletes the resource group as test-group teardown.
    """
    log = logging.getLogger('group_vars')
    vars = {
        'atd': AvereTemplateDeploy(location='northcentralus')
    }
    rg = vars['atd'].create_resource_group()
    log.info('Created Resource Group: {}'.format(rg))

    # TODO: Remove after finalizing vdbench tests.
    # vars['vserver_list'] = []
    # vars['controller_user'] = ''
    # vars['controller_ip'] = ''

    yield vars
    log.info('Deleting Resource Group: {}'.format(rg.name))
    wait_for_op(vars['atd'].delete_resource_group())


@pytest.fixture()
def ssh_client(group_vars):
    client = create_ssh_client(group_vars['controller_user'],
                               group_vars['controller_ip'])
    yield client
    client.close()


@pytest.fixture()
def scp_client(ssh_client):
    client = SCPClient(ssh_client.get_transport())
    yield client
    client.close()


# HELPER FUNCTIONS ############################################################
def wait_for_op(op, timeout_sec=60):
    """
    Wait for a long-running operation (op) for timeout_sec seconds.

    op is an AzureOperationPoller object.
    """
    log = logging.getLogger('wait_for_op')
    time_start = time()
    while not op.done():
        op.wait(timeout=timeout_sec)
        log.info('>> operation status: {0} ({1} sec)'.format(
                 op.status(), int(time() - time_start)))
    result = op.result()
    if result:
        log.info('>> operation result: {}'.format(result))
        log.info('>> result.properties: {}'.format(result.properties))
    return result


def create_ssh_client(username, hostname, port=22, password=None):
    """Creates (and returns) an SSHClient. Auth'n is via publickey."""
    ssh_client = paramiko.SSHClient()
    ssh_client.load_system_host_keys()
    ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh_client.connect(username=username, hostname=hostname, port=port,
                       password=password)
    return ssh_client


def run_ssh_commands(ssh_client, commands):
    """
    Runs a list of commands on the server connected via ssh_client.

    If sudo_prefix is True, this will add 'sudo' before supplied commands.

    Raises an Exception if any command fails (i.e., non-zero exit code).
    """
    log = logging.getLogger('run_ssh_commands')
    for cmd in commands:
        cmd = cmd.strip()
        if not cmd:  # do not run empty "commands"
            continue

        log.debug('command to run: {}'.format(cmd))
        cmd_stdin, cmd_stdout, cmd_stderr = ssh_client.exec_command(cmd)

        cmd_rc = cmd_stdout.channel.recv_exit_status()
        log.debug('command exit code: {}'.format(cmd_rc))

        cmd_stdout = ''.join(cmd_stdout.readlines())
        log.debug('command output (stdout): {}'.format(cmd_stdout))

        cmd_stderr = ''.join(cmd_stderr.readlines())
        log.debug('command output (stderr): {}'.format(cmd_stderr))

        if cmd_rc:
            raise Exception(
                '"{}" failed with exit code {}.\n\tSTDOUT: {}\n\tSTDERR: {}'
                .format(cmd, cmd_rc, cmd_stdout, cmd_stderr)
            )


if __name__ == '__main__':
    pytest.main()
