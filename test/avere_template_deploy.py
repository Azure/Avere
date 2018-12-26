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

ARGS = None
# AZ_PARAMS = {}
DEFAULT_LOCATION = 'eastus2'

RANDOM_ID = 'av' + ''.join(random.choice(ascii_lowercase + digits) for _ in range(6))
TMP_DIR = '/tmp/tmp.' + RANDOM_ID
RG_NAME = 'aapipe-' + RANDOM_ID + '-rg'
RG_CREATED = False

TEMPLATE_URL = 'https://raw.githubusercontent.com/Azure/Avere/master/src/vfxt/azuredeploy-auto.json'
TEMPLATE_LOCAL = TMP_DIR + '/' + os.path.basename(TEMPLATE_URL)
PARAMS_FILE = TMP_DIR + '/' + RANDOM_ID + '.params.json'

# FUNCTIONS ###################################################################

def create_params_json():
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

    with open(PARAMS_FILE, 'w') as params:
            json.dump(data, params)

def download_template():
    print('> Downloading template: ' + TEMPLATE_URL)
    urlretrieve(TEMPLATE_URL, filename=TEMPLATE_LOCAL)

def create_resource_group():
    global RG_CREATED
    print('> Creating resource group: ' + RG_NAME)
    _run_az_cmd('az group create --name {0} --location {1} {2}'.format(
            RG_NAME, ARGS.location, '--debug' if ARGS.az_debug else ''))
    RG_CREATED = True

def deploy_template():
    print('> Deploying template')
    cmd = """az group deployment create {0}
    --resource-group {1}
    --template-file {2}
    --parameters @{3}
    --parameters
        virtualNetworkResourceGroup={1}
        virtualNetworkName={4}-vnet
        virtualNetworkSubnetName={4}-subnet
        avereBackedStorageAccountName={4}sa
        controllerName={4}-con
        controllerAuthenticationType=password
    """.format('--debug' if ARGS.az_debug else '', RG_NAME, TEMPLATE_LOCAL,
        PARAMS_FILE, RANDOM_ID)

    _run_az_cmd(cmd)

def cleanup(starting_dir):
    os.chdir(starting_dir)
    if ARGS.skip_cleanup:
        print('> Skipping clean up')
        return
    print('> Cleaning up')
    if RG_CREATED:
        print('> Deleting resource group: ' + RG_NAME)
        _run_az_cmd('az group delete --yes --name {0} {1}'.format(
            RG_NAME, '--debug' if ARGS.az_debug else ''))

    _debug('Removing temp directory: ' + TMP_DIR)
    shutil.rmtree(TMP_DIR)

# HELPER FUNCTIONS ############################################################

# def _load_or_generate_params():
#     global AZ_PARAMS
#     if ARGS.config:
#         pass

#     if ARGS.location:
#         AZ_PARAMS['location'] = ARGS.location

def _run_az_cmd(_cmd):
    cmd = _cmd.strip()
    _debug('az command: "' + cmd + '"')

    if ARGS.print_az_cmds:
        print('az command: "' + cmd + '"')
    else:
        cmd = cmd.split()
        sys.stdout.flush()
        subprocess.check_call(cmd, stderr=subprocess.STDOUT)

def _debug(s):
    if ARGS.debug:
        print('[DEBUG]: {}'.format(s))

# MAIN ########################################################################

def main():
    global ARGS
    if not ARGS.location:
        ARGS.location = DEFAULT_LOCATION
    starting_dir = os.getcwd()
    os.mkdir(TMP_DIR)
    os.chdir(TMP_DIR)
    _debug('Starting directory: ' + starting_dir)
    _debug('Temp directory created, now CWD: ' + TMP_DIR)

    create_params_json()
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
        cleanup(starting_dir)

    print('> TEST COMPLETE. Resource Group: {} (region: {})'.format(RG_NAME, ARGS.location))
    print('> RESULT: ' + ('FAIL' if retcode else 'PASS'))
    sys.exit(retcode)

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description='Test Avere vFXT Azure template deployment.')
    # arg_parser.add_argument('-c', '--config', default=None,
    #     help='Full path to JSON config file. Default: None (generate new config)')
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
    ARGS = arg_parser.parse_args()

    main()