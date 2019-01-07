#!/usr/bin/python3

"""
Driver for testing template-based deployment of the Avere vFXT product.
"""

from time import time

import paramiko
import pytest
from scp import SCPClient

from avere_template_deploy import AvereTemplateDeploy
from azure.mgmt.resource.resources.models import DeploymentMode, TemplateLink

result = None
# TEST CASES ##################################################################
class TestDeployment:
    def test_deploy_template(self, atd, resource_group):
        global result
        op = atd.deploy()
        try:
            wait_for_op(op)
        finally:
            result = op.result()
            # print('>> operation result: {}'.format(result))
            # if result:
            #     print('>> result.properties: {}'.format(result.properties))
            #     user, server = result.properties.outputs['ssH_STRING'].split('@')
            #     ssh = createSSHClient(server, user)
            #     scp = SCPClient(ssh.get_transport())
            #     scp.get(r'~/vfxt.log', r'./vfxt.' + atd.resource_group + '.log')
    
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
def atd():
    """Instantiates an AvereTemplateDeploy object."""
    return AvereTemplateDeploy()


@pytest.fixture(scope='class')
def resource_group(atd):
    """Creates (setup step) and deletes (cleanup step) the resource group."""
    rg = atd.create_resource_group()
    print('> Created Resource Group: {}'.format(rg))
    yield rg
    print('> Deleting Resource Group: {}'.format(rg.name))
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
        print('>> operation status: {0} ({1} sec)'.format(
              op.status(), int(time() - time_start)))
    result = op.result()
    if result:
        print('>> operation result: {}'.format(result))
        print('>> result.properties: {}'.format(result.properties))
    return result


def createSSHClient(server, user):
    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(server, 22, user)
    return client


if __name__ == '__main__':
    pytest.main()
