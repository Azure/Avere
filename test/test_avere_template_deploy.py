#!/usr/bin/python3

"""
Driver for testing template-based deployment of the Avere vFXT product.
"""

from time import time

import paramiko
import pytest
from scp import SCPClient

from avere_template_deploy import AvereTemplateDeploy


# TEST CASES ##################################################################
class TestDeployment:
    def test_deploy_template(self, atd, resource_group):
        op = atd.deploy()
        try:
            wait_for_op(op)
        finally:
            result = op.result()
            print('>> operation result: {}'.format(result))
            if result:
                print('>> result.properties: {}'.format(result.properties))
                user, server = result.properties.outputs['ssH_STRING'].split('@')
                ssh = createSSHClient(server, user)
                scp = SCPClient(ssh.get_transport())
                scp.get(r'~/vfxt.log', r'./vfxt.' + atd.resource_group + '.log')


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
