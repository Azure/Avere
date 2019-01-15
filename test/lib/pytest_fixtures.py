#!/usr/bin/python3

import json
import logging
import os

import pytest
from scp import SCPClient

from arm_template_deploy import ArmTemplateDeploy
from lib import helpers


# FIXTURES ####################################################################
@pytest.fixture(scope='module')
def group_vars():
    """
    Instantiates an ArmTemplateDeploy object, creates the resource group as
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

    vars['atd_obj'] = ArmTemplateDeploy(_fields=vars.pop('atd_obj', {}))
    rg = vars['atd_obj'].create_resource_group()
    log.info('Created Resource Group: {}'.format(rg))

    yield vars

    vars['atd_obj'] = json.loads(vars['atd_obj'].serialize())
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


@pytest.fixture()
def vserver_ip_list(group_vars):
    if 'vserver_ip_list' not in group_vars:
        vserver_ips = group_vars['deploy_outputs']["vserveR_IPS"]["value"]
        group_vars['vserver_ip_list'] = helpers.split_ip_range(vserver_ips)
    return group_vars['vserver_ip_list']


if __name__ == '__main__':
    pytest.main()
