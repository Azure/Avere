#!/usr/bin/python3

import argparse
import json
import os
import random
import shutil
import subprocess
import sys
from urllib.request import urlretrieve
from string import ascii_lowercase, digits

# GLOBAL VARIABLES ############################################################

AZ_PARAMS = {}
DEFAULT_LOCATION = 'eastus2'
RESOURCE_GROUP_CREATED = False
SCRIPT_ARGS = None
SECRETS_FILE = None
TEMPLATE_URL = 'https://raw.githubusercontent.com/Azure/Avere/master/src/vfxt/azuredeploy-auto.json'
TEMPLATE_LOCAL_FILE = os.path.basename(TEMPLATE_URL)

# FUNCTIONS ###################################################################

def load_params():
    global AZ_PARAMS
    if SCRIPT_ARGS.param_file:  # Open user-specified params file.
        with open(SCRIPT_ARGS.param_file) as config_file:
            AZ_PARAMS = json.load(config_file)
    else:  # Generate and store params.
        random_id = 'av' + \
            ''.join(random.choice(ascii_lowercase + digits) for _ in range(6))
        rg_name = 'aapipe-' + random_id + '-rg'
        AZ_PARAMS = {
            'resource-group': rg_name,
            'parameters' : {
                'virtualNetworkResourceGroup': rg_name,
                'virtualNetworkName': random_id + '-vnet',
                'virtualNetworkSubnetName': random_id + '-subnet',
                'avereBackedStorageAccountName': random_id + 'sa',
                'controllerName': random_id + '-con',
                'controllerAuthenticationType': 'password'
            }
        }
        with open(AZ_PARAMS['resource-group'] + '.params.json', 'w') as outfile:
            json.dump(AZ_PARAMS, outfile)
    print('AZ_PARAMS: {}'.format(AZ_PARAMS))

    # command-line > params file > default
    if not SCRIPT_ARGS.location:
        SCRIPT_ARGS.location = AZ_PARAMS.pop('location', DEFAULT_LOCATION)

def load_secrets():
    exp_envars = [
        'controllerPassword',
        'adminPassword',
        'servicePrincipalTenant',
        'servicePrincipalAppId',
        'servicePrincipalPassword'
    ]
    data = { 'parameters': {} }
    try:
        for ev in exp_envars:
            data['parameters'][ev] = { 'value': os.environ[ev] }
    except KeyError:
        raise Exception('The following envars must be defined: ' +
            ', '.join(exp_envars))

    global SECRETS_FILE
    SECRETS_FILE = AZ_PARAMS['resource-group'] + '.secrets.json'
    with open(SECRETS_FILE, 'w') as params:
            json.dump(data, params)

def download_template():
    print('> Downloading template: ' + TEMPLATE_URL)
    urlretrieve(TEMPLATE_URL, filename=TEMPLATE_LOCAL_FILE)

def create_resource_group():
    global RESOURCE_GROUP_CREATED
    print('> Creating resource group: ' + AZ_PARAMS['resource-group'])
    _run_az_cmd('az group create --name {0} --location {1} {2}'.format(
            AZ_PARAMS['resource-group'], SCRIPT_ARGS.location,
            '--debug' if SCRIPT_ARGS.az_debug else ''))
    RESOURCE_GROUP_CREATED = True

def deploy_template():
    print('> Deploying template')
    cmd = """az group deployment create {0}
    --resource-group {1}
    --template-file {2}
    --parameters @{3}""".format('--debug' if SCRIPT_ARGS.az_debug else '',
        AZ_PARAMS['resource-group'], TEMPLATE_LOCAL_FILE, SECRETS_FILE)

    if AZ_PARAMS['parameters']:  # There are more parameters.
        cmd += "\n\t--parameters"
        for key, val in AZ_PARAMS['parameters'].items():
            cmd += "\n\t\t{0}={1}".format(key, val)

    _run_az_cmd(cmd)

def cleanup():
    os.remove(SECRETS_FILE)  # Always remove this file.
    if SCRIPT_ARGS.skip_cleanup:
        print('> Skipping clean up')
        return

    print('> Cleaning up')
    os.remove(TEMPLATE_LOCAL_FILE)
    if RESOURCE_GROUP_CREATED:
        print('> Deleting resource group: ' + AZ_PARAMS['resource-group'])
        _run_az_cmd('az group delete --yes --name {0} {1}'.format(
            AZ_PARAMS['resource-group'], '--debug' if SCRIPT_ARGS.az_debug else ''))

# HELPER FUNCTIONS ############################################################

def _run_az_cmd(_cmd):
    cmd = _cmd.strip()
    _debug('az command: "' + cmd + '"')

    if SCRIPT_ARGS.print_az_cmds:
        print('az command: "' + cmd + '"')
    else:
        cmd = cmd.split()
        sys.stdout.flush()
        subprocess.check_call(cmd, stderr=subprocess.STDOUT)

def _debug(s):
    if SCRIPT_ARGS.debug:
        print('[DEBUG]: {}'.format(s))

# MAIN ########################################################################

def main():
    load_params()
    load_secrets()
    retcode = 0  # PASS
    try:
        download_template()
        create_resource_group()
        deploy_template()
    except:
        print('><' * 40)
        print('> ERROR: test failed')
        print('><' * 40)
        retcode = 1  # FAIL
        raise
    finally:
        cleanup()

    print('> TEST COMPLETE. Resource Group: {} (region: {})'.format(
        AZ_PARAMS['resource-group'], SCRIPT_ARGS.location))
    print('> RESULT: ' + ('FAIL' if retcode else 'PASS'))
    sys.exit(retcode)

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description='Test Avere vFXT Azure template deployment.')
    arg_parser.add_argument('-pf', '--param_file', default=None,
        help='Full path to JSON params file. Default: None (generate new params)')
    arg_parser.add_argument('-l', '--location', default=None,
        help='Azure location (region short name) to use for deployment. ' +
             'Default: ' + DEFAULT_LOCATION)
    arg_parser.add_argument('-p', '--print-az-cmds', action='store_true',
        help='Print "az" commands to STDOUT instead of running them.')
    arg_parser.add_argument('-sc', '--skip-cleanup', action='store_true',
        help='Skip the cleanup step (i.e., do not delete the script-created resource group).')
    arg_parser.add_argument('-ad', '--az-debug', action='store_true',
        help='Turn on "az" command debugging.')
    arg_parser.add_argument('-d', '--debug', action='store_true',
        help='Turn on script debugging.')
    SCRIPT_ARGS = arg_parser.parse_args()

    main()