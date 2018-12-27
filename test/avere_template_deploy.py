#!/usr/bin/python3

"""
Test template-based Avere vFXT deployment.

Assumptions:
    1. The caller/script is able to write to the current working directory.
    2. Azure secrets are stored in the following environment variables:
        * AVERE_ADMIN_PW
        * AVERE_CONTROLLER_PW
        * AZURE_CLIENT_ID
        * AZURE_CLIENT_SECRET
        * AZURE_TENANT_ID
        * AZURE_SUBSCRIPTION_ID
"""

import argparse
import json
import os
import random
import subprocess
import sys
import time
from urllib.request import urlretrieve
from string import ascii_lowercase, digits
from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode

# GLOBAL VARIABLES ############################################################

DEFAULT_LOCATION = 'eastus2'
DEPLOY_PARAMS = {}
RESOURCE_GROUP_CREATED = False
SCRIPT_ARGS = None
TEMPLATE_URL = 'https://raw.githubusercontent.com/Azure/Avere/master/src/vfxt/azuredeploy-auto.json'
TEMPLATE_LOCAL_FILE = os.path.basename(TEMPLATE_URL)

# FUNCTIONS ###################################################################

def load_credentials():
    """Loads Azure credentials from environment variables."""
    print('> Load Azure credentials.')
    return ResourceManagementClient(
        credentials=ServicePrincipalCredentials(
            client_id=os.environ['AZURE_CLIENT_ID'],
            secret=os.environ['AZURE_CLIENT_SECRET'],
            tenant=os.environ['AZURE_TENANT_ID']
        ),
        subscription_id=os.environ['AZURE_SUBSCRIPTION_ID']
    )

def load_params():
    """
    Loads the parameters needed in this script (e.g., resource group name).

    If the user specified a parameters file, load those values into
    DEPLOY_PARAMS. Otherwise, generate the parameter values and store those
    values for re-use. The generated parameter values are stored in the current
    working directory as <resource-group-name>.params.json.
    """
    global DEPLOY_PARAMS
    if SCRIPT_ARGS.param_file:  # Open user-specified params file.
        with open(SCRIPT_ARGS.param_file) as config_file:
            DEPLOY_PARAMS = json.load(config_file)
    else:  # Generate and store params.
        random_id = 'av' + \
            ''.join(random.choice(ascii_lowercase + digits) for _ in range(6))
        rg_name = 'aapipe-' + random_id + '-rg'
        DEPLOY_PARAMS = {
            'resource-group': rg_name,
            'parameters': {
                'virtualNetworkResourceGroup': rg_name,
                'virtualNetworkName': random_id + '-vnet',
                'virtualNetworkSubnetName': random_id + '-subnet',
                'avereBackedStorageAccountName': random_id + 'sa',
                'controllerName': random_id + '-con',
                'controllerAuthenticationType': 'password'
            }
        }
        with open(DEPLOY_PARAMS['resource-group'] + '.params.json', 'w') as pf:
            json.dump(DEPLOY_PARAMS, pf)

    # Set location/region. Precedence: command-line > params file > default
    if not SCRIPT_ARGS.location:
        SCRIPT_ARGS.location = DEPLOY_PARAMS.pop('location', DEFAULT_LOCATION)
    _debug('SCRIPT_ARGS.location = {}'.format(SCRIPT_ARGS.location))
    _debug('DEPLOY_PARAMS (before secrets): {}'.format(DEPLOY_PARAMS))

    # Add secrets to the parameters for template deployment.
    secrets = {
        'adminPassword': os.environ['AVERE_ADMIN_PW'],
        'controllerPassword': os.environ['AVERE_CONTROLLER_PW'],
        'servicePrincipalAppId': os.environ['AZURE_CLIENT_ID'],
        'servicePrincipalPassword': os.environ['AZURE_CLIENT_SECRET'],
        'servicePrincipalTenant': os.environ['AZURE_TENANT_ID']
    }
    DEPLOY_PARAMS['parameters'] = { **DEPLOY_PARAMS['parameters'], **secrets }

def create_resource_group(rm_client):
    """
    Creates an Azure resource group.

    Assumes that the invoker has already used "az login" to authenticate.
    """
    global RESOURCE_GROUP_CREATED
    print('> Creating resource group: ' + DEPLOY_PARAMS['resource-group'])
    if not SCRIPT_ARGS.skip_az_ops:
        rg = rm_client.resource_groups.create_or_update(
            DEPLOY_PARAMS['resource-group'],
            { 'location': SCRIPT_ARGS.location }
        )
        _debug('Resource Group = {}'.format(rg))
    RESOURCE_GROUP_CREATED = True

def deploy_template(rm_client):
    """Deploys the Avere vFXT template."""
    print('> Deploying template')

    # Prepare parameters.
    parameters = {k: {'value': v} for k, v in DEPLOY_PARAMS['parameters'].items()}

    if not SCRIPT_ARGS.skip_az_ops:
        op = rm_client.deployments.create_or_update(
            resource_group_name=DEPLOY_PARAMS['resource-group'],
            deployment_name='avere-template-deploy-test',
            properties={
                'mode': DeploymentMode.incremental,
                'template': _load_template(),
                'parameters': parameters
            }
        )
        _wait_for_op(op)

def delete_resource_group(rm_client):
    """Deletes the resource group"""
    print('> Deleting resource group: ' + DEPLOY_PARAMS['resource-group'])
    if not SCRIPT_ARGS.skip_az_ops:
        op = rm_client.resource_groups.delete(DEPLOY_PARAMS['resource-group'])
        _wait_for_op(op)

def cleanup(rm_client):
    """
    Performs multiple cleanup activities.
        1. Deletes the downloaded template file.
        2. Deletes the resource group.
    """
    print('> Cleaning up')
    if os.path.isfile(TEMPLATE_LOCAL_FILE):
        os.remove(TEMPLATE_LOCAL_FILE)

    if not SCRIPT_ARGS.skip_rg_cleanup and RESOURCE_GROUP_CREATED:
        delete_resource_group(rm_client)

# HELPER FUNCTIONS ############################################################

def _load_template():
    """Downloads the Avere vFXT deployment template."""
    _debug('Downloading template: ' + TEMPLATE_URL)
    urlretrieve(TEMPLATE_URL, filename=TEMPLATE_LOCAL_FILE)
    with open(TEMPLATE_LOCAL_FILE, 'r') as template_file_fd:
        template = json.load(template_file_fd)
    return template

def _wait_for_op(op, timeout_sec=60):
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

def _debug(s):
    """Prints the passed string, with a DEBUG header, if debug is on."""
    if SCRIPT_ARGS.debug:
        print('[DEBUG]: {}'.format(s))

# MAIN ########################################################################

def main():
    """Main script driver."""
    rm_client = load_credentials()
    load_params()
    retcode = 0  # PASS
    try:
        create_resource_group(rm_client)
        deploy_template(rm_client)
    except Exception as ex:
        print('\n' + ('><' * 40))
        print('> TEST FAILED')
        print('> EXCEPTION TEXT: {}'.format(ex))
        print(('><' * 40) + '\n')
        retcode = 1  # FAIL
        raise
    except:
        retcode = 2  # FAIL
        raise
    finally:
        cleanup(rm_client)
        print('> SCRIPT COMPLETE. Resource Group: {} (region: {})'.format(
            DEPLOY_PARAMS['resource-group'], SCRIPT_ARGS.location))
        print('> RESULT: ' + ('FAIL' if retcode else 'PASS'))
    sys.exit(retcode)


if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(
        description='Test template-based Avere vFXT deployment.')

    arg_parser.add_argument('-p', '--param-file', default=None,
        help='Full path to JSON params file. ' +
             'Default: None (generate new params)')
    arg_parser.add_argument('-l', '--location', default=None,
        help='Azure location (region short name) to use for deployment. ' +
             'Default: ' + DEFAULT_LOCATION)
    arg_parser.add_argument('-xo', '--skip-az-ops', action='store_true',
        help='Do NOT actually run any of the Azure operations.')
    arg_parser.add_argument('-xc', '--skip-rg-cleanup', action='store_true',
        help='Do NOT delete the resource group during cleanup.')
    arg_parser.add_argument('-d', '--debug', action='store_true',
        help='Turn on script debugging.')
    SCRIPT_ARGS = arg_parser.parse_args()

    main()
