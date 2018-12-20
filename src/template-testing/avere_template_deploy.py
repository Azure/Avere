#!/usr/bin/python3

import os
import random
import shutil
import subprocess
import sys
from urllib.request import urlretrieve
from string import ascii_lowercase, digits

# GLOBAL VARIABLES ############################################################

DEBUG = 0
ECHO_AZ_CMDS = True

ORIG_DIR = os.getcwd()

RANDOM_ID = "av" + "".join(random.choice(ascii_lowercase + digits) for _ in range(6))
TMP_DIR = "/tmp/tmp." + RANDOM_ID
RG_NAME = "aapipe-" + RANDOM_ID + "-rg"
RG_CREATED = False

LOCATION = "eastus2"
TEMPLATE_URL = "https://raw.githubusercontent.com/Azure/Avere/master/src/vfxt/azuredeploy-auto.json"

# FUNCTIONS ###################################################################

def download_template():
    print("> Downloading template")
    urlretrieve(TEMPLATE_URL, filename=TMP_DIR + "/azuredeploy-auto.json")

def create_resource_group(loc=LOCATION):
    global RG_CREATED
    print("> Creating resource group: " + RG_NAME)
    _run_az_cmd("az group create --name {} --location {}".format(RG_NAME, loc),
        logfile="{}/az_cmds.create_rg.log".format(ORIG_DIR))
    RG_CREATED = True

def deploy_template():
    print("> Deploying template")
    cmd = """az group deployment create --debug
    --resource-group {0}
    --template-file {1}/azuredeploy-auto.json
    --parameters
        virtualNetworkResourceGroup={0}
        virtualNetworkName={2}-vnet
        virtualNetworkSubnetName={2}-subnet
        avereBackedStorageAccountName={2}sa
        controllerName={2}-con
        controllerAuthenticationType=password
        controllerPassword={3}
        adminPassword={3}
        servicePrincipalTenant={4}
        servicePrincipalAppId={5}
        servicePrincipalPassword={6}
    """.format(RG_NAME, TMP_DIR, RANDOM_ID,
            os.environ["adminPassword"],
            os.environ["servicePrincipalTenant"],
            os.environ["servicePrincipalAppId"],
            os.environ["servicePrincipalPassword"])
    _run_az_cmd(cmd, logfile="{}/az_cmds.deploy_template.log".format(ORIG_DIR))

def cleanup():
    if RG_CREATED:
        print("> Deleting resource group: " + RG_NAME)
        _run_az_cmd("az group delete --yes --name %s" % RG_NAME,
            logfile="{}/az_cmds.delete_rg.log".format(ORIG_DIR))

    print("> Removing temp directory")
    os.chdir(ORIG_DIR)
    shutil.rmtree(TMP_DIR)

# HELPER FUNCTIONS ############################################################

def _run_az_cmd(_cmd, logfile="{}/az_cmds.log".format(ORIG_DIR)):
    if ECHO_AZ_CMDS:
        cmd = ["echo", "'" + _cmd + "'"]
    else:
        cmd = _cmd.split()

    _debug("cmd = {}".format(cmd))
    sys.stdout.flush()
    with subprocess.Popen(cmd, bufsize=1,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT) as proc, \
        open(logfile, "ab") as file:
        for line in proc.stdout:
            sys.stdout.buffer.write(line)
            file.write(line)

def _debug(s):
    if DEBUG:
        print("[DEBUG]: {}".format(s))

# MAIN #########################################################################

def main(*args, **kwds):
    os.mkdir(TMP_DIR)
    os.chdir(TMP_DIR)

    retcode = 0  # SUCCESS

    try:
        download_template()
        create_resource_group()
        deploy_template()
    except:
        print("><" * 40)
        print("> ERROR: test failed")
        print("><" * 40)
        retcode = 1  # FAIL
        raise
    finally:
        cleanup()

    print("> RESULT: %s" % ("FAILURE" if retcode else "SUCCESS"))
    sys.exit(retcode)

if __name__ == "__main__":
    main(*sys.argv[1:])