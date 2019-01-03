#!/usr/bin/python3

"""
Driver for testing template-based deployment of the Avere vFXT product.
"""

from time import time

import pytest
from avere_template_deploy import AvereTemplateDeploy


# TEST CASES ##################################################################
class TestDeployment:
    def test_deploy_template(self, atd, resource_group):
        # 2018-1231: TURNED OFF FOR NOW
        # wait_for_op(atd.deploy())
        pass


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


if __name__ == '__main__':
    pytest.main()
