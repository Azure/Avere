#!/usr/bin/python3

"""
Driver for testing template-based deployment of the Avere vFXT product.
"""

import json
import logging
import os
from time import sleep

import pytest
from scp import SCPClient

from avere_template_deploy import AvereTemplateDeploy
from lib import helpers
from sshtunnel import SSHTunnelForwarder


# TEST CASES ##################################################################
class TestDeployment:

    def test_deploy_template(self, group_vars):
        log = logging.getLogger('test_deploy_template')
        td = group_vars['td_obj']
        with open(os.environ['BUILD_SOURCESDIRECTORY'] + '/src/vfxt/azuredeploy-auto.json') as tfile:
            td.template = json.load(tfile)
        with open(os.path.expanduser(r'~/.ssh/id_rsa.pub'), 'r') as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        td.deploy_params = {
            'virtualNetworkResourceGroup': td.resource_group,
            'virtualNetworkName': td.deploy_id + '-vnet',
            'virtualNetworkSubnetName': td.deploy_id + '-subnet',
            'avereBackedStorageAccountName': td.deploy_id + 'sa',
            'controllerName': td.deploy_id + '-con',
            'controllerAdminUsername': 'azureuser',
            'controllerAuthenticationType': 'sshPublicKey',
            'controllerSSHKeyData': ssh_pub_key,
            'adminPassword': os.environ['AVERE_ADMIN_PW'],
            'controllerPassword': os.environ['AVERE_CONTROLLER_PW']
        }
        group_vars['controller_name'] = td.deploy_params['controllerName']
        group_vars['controller_user'] = td.deploy_params['controllerAdminUsername']

        log.debug('Generated deploy parameters: \n{}'.format(
            json.dumps(td.deploy_params, indent=4)))
        td.deploy_name = 'test_deploy_template'
        try:
            deploy_result = helpers.wait_for_op(td.deploy())
            group_vars['deploy_outputs'] = deploy_result.properties.outputs
        finally:
            group_vars['controller_ip'] = td.nm_client.public_ip_addresses.get(
                td.resource_group,
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
        vserver_ips = group_vars['deploy_outputs']["vserveR_IPS"]["value"]
        vserver_list = helpers.splitList(vserver_ips)
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
        helpers.run_ssh_commands(ssh_client, commands)

    def test_ping_nodes(self, group_vars, ssh_client):
        commands = []
        for vs_ip in group_vars['vserver_list']:
            commands.append('ping -c 3 {}'.format(vs_ip))
        helpers.run_ssh_commands(ssh_client, commands)

    def test_node_basic_fileops(self, group_vars, ssh_client, scp_client):
        script_name = 'check_node_basic_fileops.sh'
        scp_client.put('{0}/test/{1}'.format(
                       os.environ['BUILD_SOURCESDIRECTORY'], script_name),
                       r'~/.')
        commands = """
            chmod +x {0}
            ./{0}
            """.format(script_name).split('\n')
        helpers.run_ssh_commands(ssh_client, commands)

    def test_vdbench_deploy(self, group_vars):
        td = group_vars['td_obj']
        ssh_pub_key = group_vars['ssh_pub_key']
        with open('{}/src/client/vmas/azuredeploy.json'.format(
                  os.environ['BUILD_SOURCESDIRECTORY'])) as tfile:
            td.template = json.load(tfile)
        orig_params = td.deploy_params.copy()
        td.deploy_params = {
            'uniquename': td.deploy_id,
            'sshKeyData': ssh_pub_key,
            'virtualNetworkResourceGroup': orig_params['virtualNetworkResourceGroup'],
            'virtualNetworkName': orig_params['virtualNetworkName'],
            'virtualNetworkSubnetName': orig_params['virtualNetworkSubnetName'],
            'nfsCommaSeparatedAddresses': ','.join(group_vars['vserver_list']),
            'vmCount': 12,
            'nfsExportPath': '/msazure',
            'bootstrapScriptPath': '/bootstrap/bootstrap.vdbench.sh'
        }
        td.deploy_name = 'test_vdbench'
        deploy_result = helpers.wait_for_op(td.deploy())
        group_vars['deploy_vd_outputs'] = deploy_result.properties.outputs

    def test_vdbench_template_run(self, group_vars):
        node_ip = group_vars['deploy_vd_outputs']["nodE_0_IP_ADDRESS"]["value"]
        with SSHTunnelForwarder(
            group_vars['controller_ip'],
            ssh_username=group_vars['controller_user'],
            ssh_pkey=os.path.expanduser(r'~/.ssh/id_rsa'),
            remote_bind_address=(node_ip, 22)
        ) as ssh_tunnel:
            sleep(1)
            try:
                ssh_client = helpers.create_ssh_client(
                    group_vars['controller_user'],
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
                helpers.run_ssh_commands(ssh_client, commands)
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
    vars = {}
    if 'VFXT_TEST_VARS_FILE' in os.environ and \
       os.path.isfile(os.environ['VFXT_TEST_VARS_FILE']):
        log.debug('Loading into vars from {} (VFXT_TEST_VARS_FILE)'.format(
            os.environ['VFXT_TEST_VARS_FILE']))
        with open(os.environ['VFXT_TEST_VARS_FILE'], 'r') as vtvf:
            vars = {**vars, **json.load(vtvf)}
    log.debug('Loaded the following JSON into vars: {}'.format(
        json.dumps(vars, sort_keys=True, indent=4)))

    vars['td_obj'] = AvereTemplateDeploy(_fields=vars.pop('td_obj', {}))
    rg = vars['td_obj'].create_resource_group()
    log.info('Created Resource Group: {}'.format(rg))

    yield vars

    log.info('Deleting Resource Group: {}'.format(rg.name))
    helpers.wait_for_op(vars['td_obj'].delete_resource_group())

    vars['td_obj'] = json.loads(vars['td_obj'].serialize())
    if 'VFXT_TEST_VARS_FILE' in os.environ:
        log.debug('vars: {}'.format(
            json.dumps(vars, sort_keys=True, indent=4)))
        log.debug('Saving vars to {} (VFXT_TEST_VARS_FILE)'.format(
            os.environ['VFXT_TEST_VARS_FILE']))
        with open(os.environ['VFXT_TEST_VARS_FILE'], 'w') as vtvf:
            json.dump(vars, vtvf)


@pytest.fixture()
def ssh_client(group_vars):
    client = helpers.create_ssh_client(group_vars['controller_user'],
                                       group_vars['controller_ip'])
    yield client
    client.close()


@pytest.fixture()
def scp_client(ssh_client):
    client = SCPClient(ssh_client.get_transport())
    yield client
    client.close()


if __name__ == '__main__':
    pytest.main()
