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

        logging.debug('Generated deploy parameters: \n{}'.format(
            json.dumps(atd.deploy_params, indent=4)))
        atd.deploy_name = 'test_deploy_template'
        group_vars['deploy_result'] = wait_for_op(atd.deploy())

    def test_get_vfxt_log(self, group_vars):
        atd = group_vars['atd']
        logging.info('Getting vfxt.log from controller: {}'.format(
            group_vars['controller_name']))
        con_ip = atd.nm_client.public_ip_addresses.get(
            atd.resource_group,
            'publicip-' + group_vars['controller_name']).ip_address
        group_vars['controller_ip'] = con_ip

        ssh_client = create_ssh_client(group_vars['controller_user'], con_ip)
        group_vars['ssh_client'] = ssh_client

        scp_client = SCPClient(ssh_client.get_transport())
        scp_client.get(r'~/vfxt.log',
                       r'./vfxt.' + group_vars['controller_name'] + '.log')

    def test_vdbench(self, group_vars):
        atd = group_vars['atd']
        with open(os.path.expanduser(r'~/.ssh/id_rsa.pub'), 'r') as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        result = group_vars['deploy_result']
        vserver = result.properties.outputs["vserveR_IPS"]["value"]
        x = vserver.split("-")
        ip1 = x[0]
        ip2 = x[1]
        ip1_split_list = ip1.split(".")
        ip2_split_list = ip2.split(".")
        outcome = ip1_split_list[-1]
        outcome2 = ip2_split_list[-1]

        prefix = ".".join(ip1_split_list[:-1])
        prefix += "."

        vserver_list = ",".join([prefix + str(n) for n in range(int(outcome), int(outcome2)+1)])
        ssh_client = group_vars["ssh_client"]
        # group_vars['controller_user'] = ''
        # group_vars['controller_ip'] = ''
        # ssh_client = create_ssh_client(group_vars['controller_user'], group_vars['controller_ip'])
        commands = """
            sudo apt-get update
            sudo apt-get install nfs-common
            sudo mkdir -p /nfs/node0
            sudo mkdir -p /nfs/node1
            sudo mkdir -p /nfs/node2
            sudo chown nobody:nogroup /nfs/node0
            sudo chown nobody:nogroup /nfs/node1
            sudo chown nobody:nogroup /nfs/node2
            """.split('\n')
        count = 0
        for i in vserver_list.split(','):
            command = i + ":/msazure /nfs/node"+str(count)+ " nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0"
            echo_command = 'sudo sh -c \'echo "'+ command +'" >> /etc/fstab\''
            commands.append(echo_command)
            count += 1
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
        commands = [s.strip() for s in commands if s.strip()]
        run_ssh_commands(ssh_client, commands)
        with open(os.environ['BUILD_SOURCESDIRECTORY'] + '/src/client/vmas/azuredeploy.json') as tfile:
            atd.template = json.load(tfile)
        original_params = atd.deploy_params.copy()
        atd.deploy_params = {'uniquename': 'testString',
                             'sshKeyData': ssh_pub_key,
                             'virtualNetworkResourceGroup': original_params['virtualNetworkResourceGroup'],
                             'virtualNetworkName': original_params['virtualNetworkName'],
                             'virtualNetworkSubnetName': original_params['virtualNetworkSubnetName'],
                             'nfsCommaSeparatedAddresses': vserver_list,
                             'vmCount': 12,
                             'nfsExportPath': '/msazure',
                             'bootstrapScriptPath': '/bootstrap/bootstrap.vdbench.sh'
                            }
        # rg_id = ""
        # atd.resource_group = rg_id+"-rg"
        # atd.deploy_params = {'uniquename': 'testString',
        #                      'sshKeyData': ssh_pub_key,
        #                      'virtualNetworkResourceGroup': atd.resource_group,
        #                      'virtualNetworkName': rg_id +"-vnet",
        #                      'virtualNetworkSubnetName': rg_id +"-subnet",
        #                      'nfsCommaSeparatedAddresses': vserver_list,
        #                      'vmCount': 12,
        #                      'nfsExportPath': '/msazure',
        #                      'bootstrapScriptPath': '/bootstrap/bootstrap.vdbench.sh'
        #                     }
        atd.deploy_name = 'test_vdbench'
        group_vars['deploy_vd_result'] = wait_for_op(atd.deploy())
        result_vd = group_vars['deploy_vd_result']
        node_ip = result_vd.properties.outputs["nodE_0_IP_ADDRESS"]["value"]

        with SSHTunnelForwarder(
            group_vars['controller_ip'],
            ssh_username=group_vars['controller_user'],
            ssh_pkey=os.path.expanduser(r'~/.ssh/id_rsa'),
            remote_bind_address=(node_ip, 22)
        ) as ssh_tunnel:
            sleep(1)
            ssh_client_2 = create_ssh_client(group_vars['controller_user'], '127.0.0.1', ssh_tunnel.local_bind_port)
            scp_client = SCPClient(ssh_client_2.get_transport())
            scp_client.put(os.path.expanduser(r'~/.ssh/id_rsa'), r'~/.ssh/id_rsa')
            # commands = """~/copy_idrsa.sh
            #     cd
            #     ./run_vdbench.sh inmem.conf uniquestring1
            # """.split('\n')
            # run_ssh_commands(ssh_client_2, commands)


# FIXTURES ####################################################################
@pytest.fixture(scope='class')
def group_vars():
    """
    Instantiates an AvereTemplateDeploy object, creates the resource group as
    test-group setup, and deletes the resource group as test-group teardown.
    """
    atd = AvereTemplateDeploy(location='westus')
    rg = atd.create_resource_group()
    logging.info('Created Resource Group: {}'.format(rg))
    vars = {'atd': atd, 'deploy_result': None}
    yield vars
    logging.info('Deleting Resource Group: {}'.format(rg.name))
    wait_for_op(atd.delete_resource_group())


# HELPER FUNCTIONS ############################################################
def wait_for_op(op, timeout_sec=60):
    """
    Wait for a long-running operation (op) for timeout_sec seconds.

    op is an AzureOperationPoller object.
    """
    time_start = time()
    while not op.done():
        op.wait(timeout=timeout_sec)
        logging.info('>> operation status: {0} ({1} sec)'.format(
              op.status(), int(time() - time_start)))
    result = op.result()
    if result:
        logging.info('>> operation result: {}'.format(result))
        logging.info('>> result.properties: {}'.format(result.properties))
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
    for cmd in commands:
        logging.debug('command to run: {}'.format(cmd))
        cmd_stdin, cmd_stdout, cmd_stderr = ssh_client.exec_command(cmd)

        cmd_rc = cmd_stdout.channel.recv_exit_status()
        logging.debug('command exit code: {}'.format(cmd_rc))

        cmd_stdout = ''.join(cmd_stdout.readlines())
        logging.debug('command output (stdout): {}'.format(cmd_stdout))

        cmd_stderr = ''.join(cmd_stderr.readlines())
        logging.debug('command output (stderr): {}'.format(cmd_stderr))

        if cmd_rc:
            raise Exception(
                '"{}" failed with exit code {}.\n\tSTDOUT: {}\n\tSTDERR: {}'
                .format(cmd, cmd_rc, cmd_stdout, cmd_stderr)
            )


if __name__ == '__main__':
    pytest.main()
