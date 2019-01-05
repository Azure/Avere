#!/usr/bin/python3

"""
Driver for testing template-based deployment of the Avere vFXT product.
"""

import logging
from time import time

import paramiko
import pytest
from scp import SCPClient

from avere_template_deploy import AvereTemplateDeploy


# TEST CASES ##################################################################
class TestDeployment:
    def test_deploy_template(self, group_vars):
        atd = group_vars['atd']
        group_vars['deploy_result'] = wait_for_op(atd.deploy())

    def test_get_vfxt_log(self, group_vars):
        atd = group_vars['atd']
        logging.info('> Getting vfxt.log from controller: {}'.format(
            atd.controller_name))
        controller_ip = atd.nm_client.public_ip_addresses.get(
            atd.resource_group,
            'publicip-' + atd.controller_name).ip_address
        ssh = create_ssh_client(atd.controller_user, controller_ip)
        scp = SCPClient(ssh.get_transport())
        scp.get(r'~/vfxt.log', r'./vfxt.' + atd.controller_name + '.log')


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
    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(host, port, user)
    return client


if __name__ == '__main__':
    pytest.main()
