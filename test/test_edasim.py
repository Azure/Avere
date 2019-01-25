#!/usr/bin/python3

"""
Driver for testing edasim
"""

import json
import os
from time import sleep
import logging
import pytest
import requests
from scp import SCPClient

from sshtunnel import SSHTunnelForwarder

from lib import helpers
from lib.pytest_fixtures import (averecmd_params, mnt_nodes,  # noqa: F401
                                 resource_group, storage_account, event_hub,
                                 scp_cli, ssh_con, test_vars, vs_ips)

# logging.basicConfig(level=logging.DEBUG)


class TestEdasim:
    def test_download_go(self, ssh_con):
        commands = """
            sudo apt -y install golang-go
            mkdir ~/gopath
            echo "export GOPATH=$HOME/gopath" >> ~/.profile
            echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> ~/.profile
            source ~/.profile && cd $GOPATH && go get -v github.com/Azure/Avere/src/go/...
            """.split("\n")
        helpers.run_ssh_commands(ssh_con, commands)

    def test_storage_account(self, test_vars, resource_group, storage_account, ssh_con):
        td = test_vars["atd_obj"]
        storage_keys = td.st_client.storage_accounts.list_keys(
            resource_group.name,
            storage_account.name)
        storage_keys = {v.key_name: v.value for v in storage_keys.keys}
        key = storage_keys['key1']
        print("storage_account = {}".format(storage_account.name))
        print("key = {}".format(key))
        commands = """
            export AZURE_STORAGE_ACCOUNT= {0}
            export AZURE_STORAGE_ACCOUNT_KEY={1}
            """.format(storage_account.name, key).split("\n")
        helpers.run_ssh_commands(ssh_con, commands)
        test_vars["cmd1"] = "AZURE_STORAGE_ACCOUNT=\"{}\" AZURE_STORAGE_ACCOUNT_KEY=\"{}\" ".format(storage_account.name, key)

    def test_event_hub(self, test_vars, ssh_con):
        td = test_vars["atd_obj"]
        td.template = requests.get(
                url='https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/301-eventHub-create-authrule-namespace-and-eventHub/azuredeploy.json').json()
        with open(os.path.expanduser(r'~/.ssh/id_rsa.pub'), 'r') as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        td.deploy_params = {
            'namespaceName': "edasimeventhub2",
            'namespaceAuthorizationRuleName': 'edasimeventhub',
            'eventHubName': 'edasimeventhub2',
            'eventhubAuthorizationRuleName': 'edasimeventhub',
            'eventhubAuthorizationRuleName1': 'edasimeventhub1',
            'consumerGroupName': 'edasimtest',
        }

        logging.debug('> Generated deploy parameters: \n{}'.format(
            json.dumps(td.deploy_params, indent=4)))
        deploy_result = helpers.wait_for_op(td.deploy())
        test_vars["deploy_eh_outputs"] = deploy_result.properties.outputs
        print(test_vars["deploy_eh_outputs"])
        policy_primary_key = test_vars["deploy_eh_outputs"]["eventHubSharedAccessPolicyPrimaryKey"]["value"]
        print(policy_primary_key)
        commands = """
            export AZURE_EVENTHUB_SENDERKEYNAME="RootManageSharedAccessKey"
            export AZURE_EVENTHUB_SENDERKEY={0}
            export AZURE_EVENTHUB_NAMESPACENAME="edasimeventhub2"
            """.format(policy_primary_key).split("\n")
        helpers.run_ssh_commands(ssh_con, commands)
        test_vars["cmd2"] = "AZURE_EVENTHUB_SENDERKEYNAME=\"RootManageSharedAccessKey\" AZURE_EVENTHUB_SENDERKEY=\"{}\" AZURE_EVENTHUB_NAMESPACENAME=\"edasimeventhub2\"".format(policy_primary_key)


    def test_edasim_setup(self, mnt_nodes, ssh_con):  # noqa: F811
        commands = """
            sudo mkdir -p /nfs/node0/bootstrap
            cd /nfs/node0/bootstrap
            curl --retry 5 --retry-delay 5 -o bootstrap.jobsubmitter.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.jobsubmitter.sh
            curl --retry 5 --retry-delay 5 -o bootstrap.orchestrator.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.orchestrator.sh
            curl --retry 5 --retry-delay 5 -o bootstrap.onpremjobuploader.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.onpremjobuploader.sh
            curl --retry 5 --retry-delay 5 -o bootstrap.worker.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.worker.sh
            sudo mkdir -p /nfs/node0/bootstrap/edasim
            source ~/.profile && sudo cp $GOPATH/bin/* /nfs/node0/bootstrap/edasim
            sudo mkdir -p /nfs/node0/bootstrap/rsyslog
            cd /nfs/node0/bootstrap/rsyslog
            sudo curl --retry 5 --retry-delay 5 -o 33-jobsubmitter.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/33-jobsubmitter.conf
            sudo curl --retry 5 --retry-delay 5 -o 30-orchestrator.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/30-orchestrator.conf
            sudo curl --retry 5 --retry-delay 5 -o 31-worker.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/31-worker.conf
            sudo curl --retry 5 --retry-delay 5 -o 32-onpremjobuploader.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/32-onpremjobuploader.conf
            sudo mkdir -p /nfs/node0/bootstrap/systemd
            cd /nfs/node0/bootstrap/systemd
            sudo curl --retry 5 --retry-delay 5 -o jobsubmitter.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/jobsubmitter.service
            sudo curl --retry 5 --retry-delay 5 -o onpremjobuploader.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/onpremjobuploader.service
            sudo curl --retry 5 --retry-delay 5 -o orchestrator.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/orchestrator.service
            sudo curl --retry 5 --retry-delay 5 -o worker.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/worker.service
            """.split("\n")
        helpers.run_ssh_commands(ssh_con, commands)

    def test_edasim_deploy(self, test_vars, vs_ips, ssh_con):  # noqa: F811
        td = test_vars["atd_obj"]
        td.template = requests.get(
                url='https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/template/azuredeploy.json').json()
        with open(os.path.expanduser(r'~/.ssh/id_rsa.pub'), 'r') as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        # print(">>>>> " + test_vars["cmd1"] + test_vars["cmd2"] + " <<<<<")
        # orig_params = td.deploy_params.copy()
        td.deploy_params = {
            "secureAppEnvironmentVariables": test_vars["cmd1"] + test_vars["cmd2"],
            "uniquename": td.deploy_id,
            "sshKeyData": ssh_pub_key,
            "virtualNetworkResourceGroup": td.resource_group,
            "virtualNetworkName": td.deploy_id + "-vnet",
            "virtualNetworkSubnetName": td.deploy_id + "-subnet",
            "nfsCommaSeparatedAddresses": ",".join(vs_ips),
            "nfsExportPath": "/msazure",
        }

        td.deploy_name = "test_edasim"
        deploy_result = helpers.wait_for_op(td.deploy())
        test_vars["deploy_edasim_outputs"] = deploy_result.properties.outputs


if __name__ == "__main__":
    pytest.main()
