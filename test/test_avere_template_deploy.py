#!/usr/bin/python3

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

import json
import logging
import os

import pytest

from lib.helpers import wait_for_op
from lib.pytest_fixtures import resource_group, test_vars  # noqa: F401


class TestVfxtTemplateDeploy:
    def test_deploy_template(self, resource_group, test_vars):  # noqa: F811
        log = logging.getLogger("test_deploy_template")
        td = test_vars["atd_obj"]
        with open("{}/src/vfxt/azuredeploy-auto.json".format(
                  os.environ["BUILD_SOURCESDIRECTORY"])) as tfile:
            td.template = json.load(tfile)
        with open(os.path.expanduser(r"~/.ssh/id_rsa.pub"), "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        td.deploy_params = {
            "avereClusterName": td.deploy_id + "-cluster",
            "virtualNetworkResourceGroup": td.resource_group,
            "virtualNetworkName": td.deploy_id + "-vnet",
            "virtualNetworkSubnetName": td.deploy_id + "-subnet",
            "avereBackedStorageAccountName": td.deploy_id + "sa",
            "controllerName": td.deploy_id + "-con",
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerSSHKeyData": ssh_pub_key,
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "enableCloudTraceDebugging": True,
            "avereInstanceType": "Standard_E32s_v3"
        }
        test_vars["controller_name"] = td.deploy_params["controllerName"]
        test_vars["controller_user"] = td.deploy_params["controllerAdminUsername"]

        log.debug("Generated deploy parameters: \n{}".format(
                  json.dumps(td.deploy_params, indent=4)))
        td.deploy_name = "test_deploy_template"
        try:
            deploy_result = wait_for_op(td.deploy())
            test_vars["deploy_outputs"] = deploy_result.properties.outputs
        finally:
            test_vars["controller_ip"] = td.nm_client.public_ip_addresses.get(
                td.resource_group, "publicip-" + test_vars["controller_name"]
            ).ip_address


if __name__ == "__main__":
    pytest.main()
