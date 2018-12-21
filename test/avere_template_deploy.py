#!/usr/bin/python3

import argparse
import os
import random
import shutil
import subprocess
import sys
from urllib.request import urlretrieve
from string import ascii_lowercase, digits

# GLOBAL VARIABLES ############################################################

ARGS = None

RANDOM_ID = 'av' + ''.join(random.choice(ascii_lowercase + digits) for _ in range(6))
TMP_DIR = '/tmp/tmp.' + RANDOM_ID
RG_NAME = 'aapipe-' + RANDOM_ID + '-rg'
RG_CREATED = False

TEMPLATE_URL = 'https://raw.githubusercontent.com/Azure/Avere/master/src/vfxt/azuredeploy-auto.json'

# FUNCTIONS ###################################################################

def download_template():
    print('> Downloading template: ' + TEMPLATE_URL)
    urlretrieve(TEMPLATE_URL, filename=TMP_DIR + '/azuredeploy-auto.json')

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
    --template-file {2}/azuredeploy-auto.json
    --parameters
        virtualNetworkResourceGroup={1}
        virtualNetworkName={3}-vnet
        virtualNetworkSubnetName={3}-subnet
        avereBackedStorageAccountName={3}sa
        controllerName={3}-con
        controllerAuthenticationType=password
    """.format('--debug' if ARGS.az_debug else '', RG_NAME, TMP_DIR, RANDOM_ID)

    sens_info = """
        controllerPassword={0}
        adminPassword={1}
        servicePrincipalTenant={2}
        servicePrincipalAppId={3}
        servicePrincipalPassword={4}
    """.format(os.environ['controllerPassword'],
            os.environ['adminPassword'],
            os.environ['servicePrincipalTenant'],
            os.environ['servicePrincipalAppId'],
            os.environ['servicePrincipalPassword'])

    # If this command fails, sensitive info could be in the traceback. So catch
    # any exceptions and re-raise a generic exception instead.
    try:
        _run_az_cmd(cmd, sens_info)
    except:
        raise Exception('Deployment failed. See command output for details.') from None

def cleanup(starting_dir):
    print('> Cleaning up')
    if RG_CREATED:
        print('> Deleting resource group: ' + RG_NAME)
        _run_az_cmd('az group delete --yes --name {0} {1}'.format(
            RG_NAME, '--debug' if ARGS.az_debug else ''))

    _debug('Removing temp directory: ' + TMP_DIR)
    os.chdir(starting_dir)
    shutil.rmtree(TMP_DIR)

# HELPER FUNCTIONS ############################################################

def _run_az_cmd(_cmd, _sens_info=''):
    cmd = _cmd.strip()
    _debug('az command: "' + cmd + '"')

    if ARGS.print_az_cmds:
        print('az command: "' + cmd + '"')
    else:
        cmd += " " + _sens_info.strip()
        cmd = cmd.split()
        sys.stdout.flush()
        subprocess.check_call(cmd, stderr=subprocess.STDOUT)

def _debug(s):
    if ARGS.debug:
        print('[DEBUG]: {}'.format(s))

# MAIN #########################################################################

def main():
    starting_dir = os.getcwd()
    os.mkdir(TMP_DIR)
    os.chdir(TMP_DIR)
    _debug('Starting directory: ' + starting_dir)
    _debug('Temp directory created, now CWD: ' + TMP_DIR)

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
    arg_parser = argparse.ArgumentParser(description='Test Avere vFXT Azure deployment.')
    arg_parser.add_argument('-l', '--location', default='eastus2',
        help='Azure location (region short name) to use for deployment. Default: eastus2')
    arg_parser.add_argument('-p', '--print-az-cmds', action='store_true',
        help='Print "az" commands to STDOUT instead of running them.')
    arg_parser.add_argument('-azd', '--az-debug', action='store_true',
        help='Turn on "az" command debugging.')
    arg_parser.add_argument('-d', '--debug', action='store_true',
        help='Turn on script debugging.')
    ARGS = arg_parser.parse_args()

    main()