#!/usr/bin/python3

"""
Driver for testing template-based deployment of the Avere vFXT product.
"""

import json
import logging
import os
from time import time

import requests
import paramiko
import pytest
from scp import SCPClient

from avere_template_deploy import AvereTemplateDeploy
from azure.mgmt.resource.resources.models import DeploymentMode, TemplateLink

result = None
# TEST CASES ##################################################################
class TestDeployment:

    def test_deploy_template(self, group_vars):
        atd = group_vars['atd']
        atd.template = requests.get(
                url='https://raw.githubusercontent.com/' +
                    'Azure/Avere/master/src/vfxt/azuredeploy-auto.json').json()
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
            'controllerPassword': os.environ['AVERE_CONTROLLER_PW'],
            'servicePrincipalAppId': os.environ['AZURE_CLIENT_ID'],
            'servicePrincipalPassword': os.environ['AZURE_CLIENT_SECRET'],
            'servicePrincipalTenant': os.environ['AZURE_TENANT_ID']
        }
        group_vars['controller_name'] = atd.deploy_params['controllerName']
        group_vars['controller_user'] = atd.deploy_params['controllerAdminUsername']

        logging.debug('> Generated deploy parameters: \n{}'.format(
            json.dumps(atd.deploy_params, indent=4)))
        group_vars['deploy_result'] = wait_for_op(atd.deploy())

    def test_get_vfxt_log(self, group_vars):
        atd = group_vars['atd']
        logging.info('> Getting vfxt.log from controller: {}'.format(
            group_vars['controller_name']))
        controller_ip = atd.nm_client.public_ip_addresses.get(
            atd.resource_group,
            'publicip-' + group_vars['controller_name']).ip_address
        ssh = create_ssh_client(group_vars['controller_user'], controller_ip)
        scp = SCPClient(ssh.get_transport())
        scp.get(r'~/vfxt.log',
                r'./vfxt.' + group_vars['controller_name'] + '.log')


    def test_vdbench(self, atd):
        with open(atd.ssh_pub_key_path, 'r') as ssh_pub_key_file:
                 ssh_pub_key = ssh_pub_key_file.read()
        
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
        atd.template_link = TemplateLink(uri ="https://raw.githubusercontent.com/Azure/Avere/master/src/client/vmas/azuredeploy.json")
        original_params = atd.deploy_params.copy()
        atd.deploy_params = {'uniquename': 'testString',
                             'sshKeyData': ssh_pub_key,
                             'virtualNetworkResourceGroup': original_params['virtualNetworkResourceGroup'],
                             'virtualNetworkName': original_params['virtualNetworkName'],
                             'virtualNetworkSubnetName': original_params['virtualNetworkSubnetName'],
                             'nfsCommaSeparatedAddresses': vserver_list,
                             'vmCount': 12,
                             'nfsExportPath': '/msazure',
                             'bootstrapScriptPath': '/bootstrap/bootstrap.sh'
                            }
        wait_for_op(atd.deploy(add_secrets_params=False))
    
# FIXTURES ####################################################################
@pytest.fixture(scope='class')
def group_vars():
    """
    Instantiates an AvereTemplateDeploy object, creates the resource group as
    test-group setup, and deletes the resource group as test-group teardown.
    """
    atd = AvereTemplateDeploy()
    rg = atd.create_resource_group()
    logging.info('> Created Resource Group: {}'.format(rg))
    yield {'atd': atd, 'deploy_result': None}
    logging.info('> Deleting Resource Group: {}'.format(rg.name))
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


def create_ssh_client(user, host, port=22):
    """Creates (and returns) an SSHClient. Auth'n is via publickey."""
    ssh_client = paramiko.SSHClient()
    ssh_client.load_system_host_keys()
    ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh_client.connect(host, port, user)
    return ssh_client


if __name__ == '__main__':
    pytest.main()
