#!/usr/bin/python3

"""
Driver for testing template-based deployment of the Avere vFXT product.
"""

import time

import pytest
from avere_template_deploy import AvereTemplateDeploy


# FIXTURES ####################################################################
@pytest.fixture(scope='class')
def atd():
    return AvereTemplateDeploy()


@pytest.fixture(scope='class')
def resource_group(atd):
    rg = atd.create_resource_group()
    print('> Created Resource Group: {}'.format(rg))
    yield rg
    print('> Deleting Resource Group: {}'.format(rg.name))
    wait_for_op(atd.delete_resource_group())


# TEST CASES ##################################################################
class TestDeployment:
    def test_deploy_template(self, resource_group):
        # 2018-1231: TURNED OFF FOR NOW
        # wait_for_op(atd.deploy())
        pass


# HELPER FUNCTIONS ############################################################
def wait_for_op(op, timeout_sec=60):
    """
    Wait for a long-running operation (op) for timeout_sec seconds.

    op is an AzureOperationPoller object.
    """
    time_start = time.time()
    while not op.done():
        op.wait(timeout=timeout_sec)
        print('>> operation status: {0} ({1} sec)'.format(
              op.status(), int(time.time() - time_start)))
    result = op.result()
    if result:
        print('>> operation result: {}'.format(result))


if __name__ == '__main__':
    pytest.main()
