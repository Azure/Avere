#!/usr/bin/python3
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

# standard imports
import json
import logging
import os
import sys
import time
from uuid import uuid4

# from requirements.txt
import pytest

# local libraries
from lib.helpers import get_vm_ips, split_ip_range, wait_for_op


class TestVfxtTemplateDeploy:
    # TODO: modularize common code
    def test_deploy_template(self, resource_group, test_vars):  # noqa: F811
        """
        Deploy a vFXT cluster.
          - create a new VNET
          - use an Avere-backed storage account
        """
        log = logging.getLogger("test_deploy_template")
        atd = test_vars["atd_obj"]
        with open("{}/src/vfxt/azuredeploy-auto.json".format(
                  test_vars["build_root"])) as tfile:
            atd.template = json.load(tfile)
        with open(test_vars["ssh_pub_key"], "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        atd.deploy_params = {
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "avereBackedStorageAccountName": atd.deploy_id + "sa",
            "avereClusterName": atd.deploy_id + "-cluster",
            "avereInstanceType": "Standard_E32s_v3",
            "avereNodeCount": 3,
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerName": atd.deploy_id + "-con",
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "controllerSSHKeyData": ssh_pub_key,
            "enableCloudTraceDebugging": True,
            "rbacRoleAssignmentUniqueId": str(uuid4()),

            "createVirtualNetwork": True,
            "virtualNetworkName": atd.deploy_id + "-vnet",
            "virtualNetworkResourceGroup": atd.resource_group,
            "virtualNetworkSubnetName": atd.deploy_id + "-subnet",
        }

        test_vars["storage_account"] = atd.deploy_params["avereBackedStorageAccountName"]
        test_vars["controller_name"] = atd.deploy_params["controllerName"]
        test_vars["controller_user"] = atd.deploy_params["controllerAdminUsername"]
        log.debug("Generated deploy parameters: \n{}".format(
                  json.dumps(atd.deploy_params, indent=4)))

        atd.deploy_name = "test_deploy_template"
        try:
            deploy_outputs = wait_for_op(atd.deploy()).properties.outputs
            test_vars["cluster_mgmt_ip"] = deploy_outputs["mgmt_ip"]["value"]
            test_vars["cluster_vs_ips"] = split_ip_range(deploy_outputs["vserver_ips"]["value"])
        finally:
            # (c_priv_ip, c_pub_ip) = get_vm_ips(
            #     atd.nm_client, atd.resource_group, test_vars["controller_name"])
            # test_vars["controller_ip"] = c_pub_ip or c_priv_ip
            test_vars["public_ip"] = atd.nm_client.public_ip_addresses.get(
                atd.resource_group, "publicip-" + test_vars["controller_name"]
            ).ip_address
            test_vars["controller_ip"] = test_vars["public_ip"]

    def test_no_storage_account_deploy(self, resource_group, test_vars):  # noqa: E501, F811
        """
        Deploy a vFXT cluster.
          - create a new VNET
          - do NOT use an Avere-backed storage account
        """
        log = logging.getLogger("test_no_storage_account_deploy")
        atd = test_vars["atd_obj"]
        with open("{}/src/vfxt/azuredeploy-auto.json".format(
                  test_vars["build_root"])) as tfile:
            atd.template = json.load(tfile)
        with open(test_vars["ssh_pub_key"], "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        atd.deploy_params = {
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "avereClusterName": atd.deploy_id + "-cluster",
            "avereInstanceType": "Standard_E32s_v3",
            "avereNodeCount": 3,
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerName": atd.deploy_id + "-con",
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "controllerSSHKeyData": ssh_pub_key,
            "enableCloudTraceDebugging": True,
            "rbacRoleAssignmentUniqueId": str(uuid4()),

            "createVirtualNetwork": True,
            "virtualNetworkName": atd.deploy_id + "-vnet",
            "virtualNetworkResourceGroup": atd.resource_group,
            "virtualNetworkSubnetName": atd.deploy_id + "-subnet",

            "useAvereBackedStorageAccount": False,
            "avereBackedStorageAccountName": atd.deploy_id + "sa",  # BUG
        }

        test_vars["controller_name"] = atd.deploy_params["controllerName"]
        test_vars["controller_user"] = atd.deploy_params["controllerAdminUsername"]
        log.debug("Generated deploy parameters: \n{}".format(
                  json.dumps(atd.deploy_params, indent=4)))

        atd.deploy_name = "test_no_storage_account_deploy"
        try:
            deploy_outputs = wait_for_op(atd.deploy()).properties.outputs
            test_vars["cluster_mgmt_ip"] = deploy_outputs["mgmt_ip"]["value"]
            test_vars["cluster_vs_ips"] = split_ip_range(deploy_outputs["vserver_ips"]["value"])
            time.sleep(60)
        finally:
            # (c_priv_ip, c_pub_ip) = get_vm_ips(
            #     atd.nm_client, atd.resource_group, test_vars["controller_name"])
            # test_vars["controller_ip"] = c_pub_ip or c_priv_ip
            test_vars["public_ip"] = atd.nm_client.public_ip_addresses.get(
                atd.resource_group, "publicip-" + test_vars["controller_name"]
            ).ip_address
            test_vars["controller_ip"] = test_vars["public_ip"]

    def test_byovnet_deploy(self, ext_vnet, resource_group, test_vars):  # noqa: E501, F811
        """
        Deploy a vFXT cluster.
          - do NOT create a new VNET
          - use an Avere-backed storage account
        """
        log = logging.getLogger("test_byovnet_deploy")
        atd = test_vars["atd_obj"]
        with open("{}/src/vfxt/azuredeploy-auto.json".format(
                  test_vars["build_root"])) as tfile:
            atd.template = json.load(tfile)
        with open(test_vars["ssh_pub_key"], "r") as ssh_pub_f:
            ssh_pub_key = ssh_pub_f.read()
        atd.deploy_params = {
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "avereBackedStorageAccountName": atd.deploy_id + "sa",
            "avereClusterName": atd.deploy_id + "-cluster",
            "avereInstanceType": "Standard_E32s_v3",
            "avereNodeCount": 3,
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerName": atd.deploy_id + "-con",
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "controllerSSHKeyData": ssh_pub_key,
            "enableCloudTraceDebugging": True,
            "rbacRoleAssignmentUniqueId": str(uuid4()),

            "createVirtualNetwork": False,
            "virtualNetworkResourceGroup": ext_vnet["resource_group"]["value"],
            "virtualNetworkName": ext_vnet["virtual_network_name"]["value"],
            "virtualNetworkSubnetName": ext_vnet["subnet_name"]["value"],
        }

        test_vars["storage_account"] = atd.deploy_params["avereBackedStorageAccountName"]
        test_vars["controller_name"] = atd.deploy_params["controllerName"]
        test_vars["controller_user"] = atd.deploy_params["controllerAdminUsername"]
        log.debug("Generated deploy parameters: \n{}".format(
                  json.dumps(atd.deploy_params, indent=4)))

        atd.deploy_name = "test_byovnet_deploy"
        try:
            deploy_outputs = wait_for_op(atd.deploy()).properties.outputs
            test_vars["cluster_mgmt_ip"] = deploy_outputs["mgmt_ip"]["value"]
            test_vars["cluster_vs_ips"] = split_ip_range(deploy_outputs["vserver_ips"]["value"])
        finally:
            test_vars["controller_ip"] = get_vm_ips(
                atd.nm_client, atd.resource_group, test_vars["controller_name"]
            )[0]
            test_vars["public_ip"] = ext_vnet["public_ip_address"]["value"]


if __name__ == "__main__":
    pytest.main(sys.argv)
