#!/usr/bin/python3

"""
Driver for testing EDASIM
"""

# standard imports
import json
import logging
import os
import sys
from time import sleep


# from requirements.txt
import pytest
import requests
from sshtunnel import SSHTunnelForwarder
from scp import SCPClient

# local libraries
from lib.helpers import create_ssh_client, run_ssh_commands, wait_for_op



class TestEdasim:
    def test_download_go(self, ssh_con):  # noqa: F811
        commands = """
            sudo apt -y install golang-go
            mkdir -p ~/gopath
            echo "export GOPATH=$HOME/gopath" >> ~/.profile
            echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> ~/.profile
            source ~/.profile && cd $GOPATH && go get -v github.com/Azure/Avere/src/go/...
            """.split("\n")
        run_ssh_commands(ssh_con, commands)

    def test_storage_account(self, resource_group, ssh_con, storage_account, test_vars):  # noqa: F811, E501
        log = logging.getLogger("test_storage_account")
        atd = test_vars["atd_obj"]
        storage_keys = atd.st_client.storage_accounts.list_keys(
            resource_group.name,
            storage_account.name)
        storage_keys = {v.key_name: v.value for v in storage_keys.keys}
        key = storage_keys['key1']
        log.debug("storage_account = {}".format(storage_account.name))
        log.debug("key = {}".format(key))
        commands = """
            export AZURE_STORAGE_ACCOUNT= {0}
            export AZURE_STORAGE_ACCOUNT_KEY={1}
            """.format(storage_account.name, key).split("\n")
        run_ssh_commands(ssh_con, commands)
        test_vars["cmd1"] = "AZURE_STORAGE_ACCOUNT=\"{}\" AZURE_STORAGE_ACCOUNT_KEY=\"{}\" ".format(storage_account.name, key)

    def test_event_hub(self, ssh_con, test_vars):  # noqa: F811
        log = logging.getLogger("test_event_hub")
        atd = test_vars["atd_obj"]
        atd.template = requests.get(
                url='https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/301-eventHub-create-authrule-namespace-and-eventHub/azuredeploy.json').json()
        eh_name = "eh-" + atd.deploy_id
        atd.deploy_params = {
            "namespaceName": eh_name + "-ns",
            "namespaceAuthorizationRuleName": eh_name + "-nsar",
            "eventHubName": eh_name,
            "eventhubAuthorizationRuleName": eh_name + "-ehar",
            "eventhubAuthorizationRuleName1": eh_name + "-ehar1",
            "consumerGroupName": eh_name + "-cgn",
        }
        atd.deploy_name = "test_event_hub"
        log.debug('Generated deploy parameters: \n{}'.format(
            json.dumps(atd.deploy_params, indent=4)))
        deploy_result = wait_for_op(atd.deploy())
        test_vars["deploy_eh_outputs"] = deploy_result.properties.outputs
        log.debug(test_vars["deploy_eh_outputs"])
        policy_primary_key = test_vars["deploy_eh_outputs"]["eventHubSharedAccessPolicyPrimaryKey"]["value"]
        log.debug("policy_primary_key = {}".format(policy_primary_key))
        commands = """
            export AZURE_EVENTHUB_SENDERKEYNAME="RootManageSharedAccessKey"
            export AZURE_EVENTHUB_SENDERKEY={0}
            export AZURE_EVENTHUB_NAMESPACENAME="edasimeventhub2"
            """.format(policy_primary_key).split("\n")
        run_ssh_commands(ssh_con, commands)
        test_vars["cmd2"] = "AZURE_EVENTHUB_SENDERKEYNAME=\"RootManageSharedAccessKey\" AZURE_EVENTHUB_SENDERKEY=\"{}\" AZURE_EVENTHUB_NAMESPACENAME=\"edasimeventhub2\"".format(policy_primary_key)

    def test_edasim_setup(self, mnt_nodes, ssh_con):  # noqa: F811
        commands = """
            sudo mkdir -p /nfs/node0/bootstrap
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.jobsubmitter.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.jobsubmitter.sh
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.orchestrator.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.orchestrator.sh
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.onpremjobuploader.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.onpremjobuploader.sh
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.worker.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/bootstrap.worker.sh
            sudo mkdir -p /nfs/node0/bootstrap/edasim
            source ~/.profile && sudo cp $GOPATH/bin/* /nfs/node0/bootstrap/edasim
            sudo mkdir -p /nfs/node0/bootstrap/rsyslog
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/rsyslog/33-jobsubmitter.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/33-jobsubmitter.conf
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/rsyslog/30-orchestrator.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/30-orchestrator.conf
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/rsyslog/31-worker.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/31-worker.conf
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/rsyslog/32-onpremjobuploader.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/32-onpremjobuploader.conf
            sudo mkdir -p /nfs/node0/bootstrap/systemd
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/systemd/jobsubmitter.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/jobsubmitter.service
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/systemd/onpremjobuploader.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/onpremjobuploader.service
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/systemd/orchestrator.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/orchestrator.service
            sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/systemd/worker.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/worker.service
            """.split("\n")
        run_ssh_commands(ssh_con, commands)

    def test_edasim_deploy(self, test_vars):  # noqa: F811
        atd = test_vars["atd_obj"]
        with open(os.path.expanduser(r'~/.ssh/id_rsa.pub'), 'r') as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        with open("{}/src/go/cmd/edasim/deploymentartifacts/template/azuredeploy.json".format(
                  os.environ["BUILD_SOURCESDIRECTORY"])) as tfile:
            atd.template = json.load(tfile)
        atd.deploy_params = {
            "secureAppEnvironmentVariables": test_vars["cmd1"] + test_vars["cmd2"],
            "uniquename": atd.deploy_id,
            "sshKeyData": ssh_pub_key,
            "virtualNetworkResourceGroup": atd.resource_group,
            "virtualNetworkName": atd.deploy_id + "-vnet",
            "virtualNetworkSubnetName": atd.deploy_id + "-subnet",
            "nfsCommaSeparatedAddresses": ",".join(test_vars["cluster_vs_ips"]),
            "nfsExportPath": "/msazure",
        }
        atd.deploy_name = "test_edasim_deploy"
        deploy_result = wait_for_op(atd.deploy())
        test_vars["deploy_edasim_outputs"] = deploy_result.properties.outputs

    def test_edasim_run(self, test_vars, storage_account, resource_group):  # noqa: F811
        log = logging.getLogger("test_edasim_run")
        node_ip = test_vars["deploy_edasim_outputs"]["jobsubmitter_0_ip_address"]["value"]
        atd = test_vars["atd_obj"]
        storage_keys = atd.st_client.storage_accounts.list_keys(
            resource_group.name,
            storage_account.name)
        storage_keys = {v.key_name: v.value for v in storage_keys.keys}
        key = storage_keys['key1']
        with SSHTunnelForwarder(
            test_vars["controller_ip"],
            ssh_username=test_vars["controller_user"],
            ssh_pkey=os.path.expanduser(r"~/.ssh/id_rsa"),
            remote_bind_address=(node_ip, 22),
        ) as ssh_tunnel:
            sleep(1)
            try:
                ssh_client = create_ssh_client(
                    test_vars["controller_user"],
                    "127.0.0.1",
                    ssh_tunnel.local_bind_port,
                )
                scp_client = SCPClient(ssh_client.get_transport())
                try:
                    scp_client.put(os.path.expanduser(r"~/.ssh/id_rsa"),
                                   r"~/.ssh/id_rsa")
                finally:
                    scp_client.close()
                commands = """
                    export AZURE_STORAGE_ACCOUNT={0}
                    export AZURE_STORAGE_ACCOUNT_KEY={1}
                    ./jobrun.sh testrun
                    """.format(storage_account.name, key).split("\n")
                run_ssh_commands(ssh_client, commands)
            finally:
                ssh_client.close()


if __name__ == "__main__":
    pytest.main(sys.argv)
