#!/usr/bin/python3
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
# import json
import json
import os
import sys
from uuid import uuid4

import pytest


class TestUnitDeploy:
    def test_json_vfxt_deploy(self, setup_unit):
        deploy_id = setup_unit.get("deploy_id")
        resource_group = setup_unit.get("resource_group")

        with open("src/vfxt/azuredeploy-auto.json") as tfile:
            schema = json.load(tfile)

        # The data to be tested:
        data = {
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "avereBackedStorageAccountName": deploy_id + "sa",
            "avereClusterName": deploy_id + "-cluster",
            "avereClusterRole": "Avere Cluster Runtime Operator",
            "avereInstanceType": "Standard_E32s_v3",
            "avereNodeCount": 3,
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerName": deploy_id + "-con",
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "controllerSSHKeyData": "string",
            "enableCloudTraceDebugging": True,
            "rbacRoleAssignmentUniqueId": str(uuid4()),
            "createVirtualNetwork": True,
            "virtualNetworkName": deploy_id + "-vnet",
            "virtualNetworkResourceGroup": resource_group,
            "virtualNetworkSubnetName": deploy_id + "-subnet",
        }

        assert self.checkdata(schema, data)

    def test_json_vfxt_negative_deploy(self, setup_unit):
        deploy_id = setup_unit.get("deploy_id")
        resource_group = setup_unit.get("resource_group")
        with open("src/vfxt/azuredeploy-auto.json") as tfile:
            schema = json.load(tfile)

        # The data to be tested:
        # enableCloudTrace is wrong
        data = {
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "avereBackedStorageAccountName": deploy_id + "sa",
            "avereClusterName": deploy_id + "-cluster",
            "avereClusterRole": "Avere Cluster Runtime Operator",
            "avereInstanceType": "Standard_E32s_v3",
            "avereNodeCount": False,
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerName": deploy_id + "-con",
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "controllerSSHKeyData": "string",
            "enableCloudTraceDebugging": 2,
            "rbacRoleAssignmentUniqueId": str(uuid4()),
            "createVirtualNetwork": True,
            "virtualNetworkName": deploy_id + "-vnet",
            "virtualNetworkResourceGroup": resource_group,
            "virtualNetworkSubnetName": deploy_id + "-subnet",
        }

        assert self.checkdata(schema, data) is False

    def test_json_vdbench_deploy(self, setup_unit):
        deploy_id = setup_unit.get("deploy_id")
        resource_group = setup_unit.get("resource_group")
        with open("src/client/vmas/azuredeploy.json") as tfile:
            schema = json.load(tfile)

        # The data to be tested:
        data = {
            "uniquename": deploy_id,
            "sshKeyData": "sshPublicKey",
            "virtualNetworkResourceGroup": resource_group,
            "virtualNetworkName": deploy_id + "-vnet",
            "virtualNetworkSubnetName": deploy_id + "-subnet",
            "nfsCommaSeparatedAddresses": "10.0.0.4, 10.0.0.5",
            "vmCount": 12,
            "nfsExportPath": "/msazure",
            "bootstrapScriptPath": "/bootstrap/bootstrap.vdbench.sh",
        }

        assert self.checkdata(schema, data)

    def test_json_vdbench_negative_deploy(self, setup_unit):
        deploy_id = setup_unit.get("deploy_id")
        resource_group = setup_unit.get("resource_group")
        with open("src/client/vmas/azuredeploy.json") as tfile:
            schema = json.load(tfile)

        # The data to be tested:
        # virtualNetwrokName is wrong
        data = {
            "uniquename": deploy_id,
            "sshKeyData": 2,
            "virtualNetworkResourceGroup": resource_group,
            "virtualNetworkName": True,
            "virtualNetworkSubnetName": deploy_id + "-subnet",
            "nfsCommaSeparatedAddresses": "10.0.0.4, 10.0.0.5",
            "vmCount": 12,
            "nfsExportPath": "/msazure",
            "bootstrapScriptPath": "/bootstrap/bootstrap.vdbench.sh",
        }

        assert self.checkdata(schema, data) is False

    def test_incorrect_keys(self, setup_unit):
        with open("src/vfxt/azuredeploy-auto.json") as tfile:
            schema = json.load(tfile)
        # The wrong data to be tested:
        data = {
            "fake_key": "fake",
        }
        assert self.check_key(schema, data) is False

    def test_correct_keys(self, setup_unit):
        deploy_id = setup_unit.get("deploy_id")
        resource_group = setup_unit.get("resource_group")
        with open("src/vfxt/azuredeploy-auto.json") as tfile:
            schema = json.load(tfile)
        # The data to be tested:
        data = {
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "avereBackedStorageAccountName": deploy_id + "sa",
            "avereClusterName": deploy_id + "-cluster",
            "avereClusterRole": "Avere Cluster Runtime Operator",
            "avereInstanceType": "Standard_E32s_v3",
            "avereNodeCount": 3,
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerName": deploy_id + "-con",
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "controllerSSHKeyData": "string",
            "enableCloudTraceDebugging": True,
            "rbacRoleAssignmentUniqueId": str(uuid4()),
            "createVirtualNetwork": True,
            "virtualNetworkName": deploy_id + "-vnet",
            "virtualNetworkResourceGroup": resource_group,
            "virtualNetworkSubnetName": deploy_id + "-subnet",
        }

        assert self.check_key(schema, data)

    def checkdata(self, schema, data):
        schema_types = {}
        for k, v in schema["parameters"].items():
            if v["type"] == "securestring" or v["type"] == "string":
                type_str = "str"
            else:
                type_str = v["type"]
            schema_types[k] = {"type": type_str}

        for key, item in data.items():
            if isinstance(item, eval(schema_types[key]["type"])):
                True
            else:
                return False
        return True

    def check_key(self, schema, data):
        for key, item in data.items():
            if key not in schema["parameters"]:
                return False

        return True


if __name__ == "__main__":
    pytest.main(sys.argv)
