#!/usr/bin/python3

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

# standard imports
import json
import logging
import os
import sys

# from requirements.txt
import pytest

# local libraries
from lib.helpers import split_ip_range, wait_for_op
from lib.pytest_fixtures import resource_group, test_vars  # noqa: F401


class TestVfxtTemplateDeploy:
    def test_deploy_template(self, resource_group, test_vars):  # noqa: F811
        log = logging.getLogger("test_deploy_template")
        atd = test_vars["atd_obj"]
        with open("{}/src/vfxt/azuredeploy-auto.json".format(
                  os.environ["BUILD_SOURCESDIRECTORY"])) as tfile:
            atd.template = json.load(tfile)
        with open(os.path.expanduser(r"~/.ssh/id_rsa.pub"), "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        atd.deploy_params = {
            "avereClusterName": atd.deploy_id + "-cluster",
            "virtualNetworkResourceGroup": atd.resource_group,
            "virtualNetworkName": atd.deploy_id + "-vnet",
            "virtualNetworkSubnetName": atd.deploy_id + "-subnet",
            "avereBackedStorageAccountName": atd.deploy_id + "sa",
            "controllerName": atd.deploy_id + "-con",
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerSSHKeyData": ssh_pub_key,
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "enableCloudTraceDebugging": True,
            "avereInstanceType": "Standard_D16s_v3"
        }
        test_vars["controller_name"] = atd.deploy_params["controllerName"]
        test_vars["controller_user"] = atd.deploy_params["controllerAdminUsername"]
        test_vars["storage_account"] = atd.deploy_params["avereBackedStorageAccountName"]

        log.debug("Generated deploy parameters: \n{}".format(
                  json.dumps(atd.deploy_params, indent=4)))
        atd.deploy_name = "test_deploy_template"
        try:
            deploy_outputs = wait_for_op(atd.deploy()).properties.outputs
            test_vars["cluster_mgmt_ip"] = deploy_outputs["mgmt_ip"]["value"]
            test_vars["cluster_vs_ips"] = split_ip_range(deploy_outputs["vserver_ips"]["value"])
        finally:
            test_vars["controller_ip"] = atd.nm_client.public_ip_addresses.get(
                atd.resource_group, "publicip-" + test_vars["controller_name"]
            ).ip_address


if __name__ == "__main__":
    pytest.main(sys.argv)
