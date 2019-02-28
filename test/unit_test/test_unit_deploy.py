#!/usr/bin/python3
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
# import json
import os
from datetime import datetime
from random import choice
from string import ascii_lowercase
from uuid import uuid4
import unittest
import json


class TestUnitDeploy(unittest.TestCase):
    def setUp(
        self,
        deploy_id=None,
        deploy_name="azurePySDK",
        location="westus2",
        resource_group=None,
        _fields={},
    ):
        """Initialize, authenticate to Azure."""
        self.deploy_id = _fields.pop("deploy_id", deploy_id)
        self.deploy_name = _fields.pop("deploy_name", deploy_name)
        self.location = _fields.pop("location", location)
        self.resource_group = _fields.pop("resource_group", resource_group)

        if not self.deploy_id:
            self.deploy_id = (
                "av"
                + datetime.utcnow().strftime("%m%dx%H%M%S")
                + choice(ascii_lowercase)
            )

        if not self.resource_group:
            self.resource_group = self.deploy_id + "-rg"

    def test_json_vfxt_deploy(self):
        # deploy template
        with open("src/vfxt/azuredeploy-auto.json") as tfile:
            schema = json.load(tfile)

        # The data to be tested:
        data = {
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "avereBackedStorageAccountName": self.deploy_id + "sa",
            "avereClusterName": self.deploy_id + "-cluster",
            "avereClusterRole": "Avere Cluster Runtime Operator",
            "avereInstanceType": "Standard_E32s_v3",
            "avereNodeCount": 3,
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerName": self.deploy_id + "-con",
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "controllerSSHKeyData": "string",
            "enableCloudTraceDebugging": True,
            "rbacRoleAssignmentUniqueId": str(uuid4()),
            "createVirtualNetwork": True,
            "virtualNetworkName": self.deploy_id + "-vnet",
            "virtualNetworkResourceGroup": self.resource_group,
            "virtualNetworkSubnetName": self.deploy_id + "-subnet",
        }

        testvalue = self.checkdata(schema, data)
        self.assertTrue(testvalue)

    def test_json_vfxt_negative_deploy(self):
        # deploy template
        with open("src/vfxt/azuredeploy-auto.json") as tfile:
            schema = json.load(tfile)

        # The data to be tested:
        data = {
            "adminPassword": os.environ["AVERE_ADMIN_PW"],
            "avereBackedStorageAccountName": self.deploy_id + "sa",
            "avereClusterName": self.deploy_id + "-cluster",
            "avereClusterRole": "Avere Cluster Runtime Operator",
            "avereInstanceType": "Standard_E32s_v3",
            "avereNodeCount": False,
            "controllerAdminUsername": "azureuser",
            "controllerAuthenticationType": "sshPublicKey",
            "controllerName": self.deploy_id + "-con",
            "controllerPassword": os.environ["AVERE_CONTROLLER_PW"],
            "controllerSSHKeyData": "string",
            "enableCloudTraceDebugging": 2,
            "rbacRoleAssignmentUniqueId": str(uuid4()),
            "createVirtualNetwork": True,
            "virtualNetworkName": self.deploy_id + "-vnet",
            "virtualNetworkResourceGroup": self.resource_group,
            "virtualNetworkSubnetName": self.deploy_id + "-subnet",
        }

        testvalue = self.checkdata(schema, data)
        self.assertFalse(testvalue)

    def test_json_vdbench_deploy(self):
        # deploy template
        with open("src/client/vmas/azuredeploy.json") as tfile:
            schema = json.load(tfile)

        # The data to be tested:
        data = {
            "uniquename": self.deploy_id,
            "sshKeyData": "sshPublicKey",
            "virtualNetworkResourceGroup": self.resource_group,
            "virtualNetworkName": self.deploy_id + "-vnet",
            "virtualNetworkSubnetName": self.deploy_id + "-subnet",
            "nfsCommaSeparatedAddresses": "10.0.0.4, 10.0.0.5",
            "vmCount": 12,
            "nfsExportPath": "/msazure",
            "bootstrapScriptPath": "/bootstrap/bootstrap.vdbench.sh",
        }

        testvalue = self.checkdata(schema, data)
        self.assertTrue(testvalue)

    def test_json_vdbench_negative_deploy(self):
        # deploy template
        with open("src/client/vmas/azuredeploy.json") as tfile:
            schema = json.load(tfile)

        # The data to be tested:
        data = {
            "uniquename": self.deploy_id,
            "sshKeyData": 2,
            "virtualNetworkResourceGroup": self.resource_group,
            "virtualNetworkName": True,
            "virtualNetworkSubnetName": self.deploy_id + "-subnet",
            "nfsCommaSeparatedAddresses": "10.0.0.4, 10.0.0.5",
            "vmCount": 12,
            "nfsExportPath": "/msazure",
            "bootstrapScriptPath": "/bootstrap/bootstrap.vdbench.sh",
        }

        testvalue = self.checkdata(schema, data)
        self.assertFalse(testvalue)

    def checkdata(self, schema, data):
        schema_types = {}
        for k, v in schema["parameters"].items():
            if v["type"] == "securestring" or v["type"] == "string":
                type_str = "str"
            else:
                type_str = v["type"]
            schema_types[k] = {"type": type_str}

        testvalue = True
        for key, item in data.items():
            if isinstance(item, eval(schema_types[key]["type"])) or testvalue is False:
                testvalue = True
            else:
                testvalue = False
                break

        return testvalue


if __name__ == "__main__":
    unittest.main()

# if i wrote the schema myself
# schema = {
#     "type": "object",
#     "properties": {
#         "adminPassword": {"type": "string"},
#         "avereBackedStorageAccountName": {"type": "string"},
#         "avereClusterName": {"type": "string"},
#         "avereClusterRole": {"type": "string"},
#         "avereInstanceType": {"type": "string"},
#         "avereNodeCount": {"type": "number"},
#         "controllerAdminUsername": {"type": "string"},
#         "controllerAuthenticationType": {"type": "string"},
#         "controllerName": {"type": "string"},
#         "controllerPassword": {"type": "string"},
#         "controllerSSHKeyData": {"type": "string"},
#         "enableCloudTraceDebugging": {"type": "boolean"},
#         "rbacRoleAssignmentUniqueId": {"type": "string"},
#         "createVirtualNetwork": {"type": "boolean"},
#         "virtualNetworkName": {"type": "string"},
#         "virtualNetworkResourceGroup": {"type": "string"},
#         "virtualNetworkSubnetName": {"type": "string"},
#     },
# }
# for idx, item in enumerate(data):
#    try:
#        validate(item, schema)
#        print("pass test")
#    except jsonschema.exceptions.ValidationError as ve:
#        print("fail test")

#
# other stuff i tried lol
#
# print(item)
# print(type(item[1]))
# print(schema["parameters"][item[0]]["type"])
#         validate(item, schema["parameters"][item])
#         # if(isinstance(type(item[1]), type(schema["parameters"][item[0]]["type"]))):
#         pass_phase = "Test passed"
#         print("testpassed")
#


#  more stuff i tried
# for key, item in data.items():
#     # print(type(item))
#     # print(schema["parameters"][key]["type"])
#     x = schema["parameters"][key]["type"]
#     if x == "string":
#         y = "string"
#     elif x == "int":
#         y = 1
#     elif x == "bool":
#         y = True
#     elif x == "securestring":
#         y = "string"
#     else:
#         y = None

#     # print(type(y))
#     if isinstance(item, type(y)):
#         print("testpassed")
#     else:
#         print("testfailed")
#         self.fail("testshouldfail")


# except jsonschema.exceptions.ValidationError as ve:
#  print("testfailed")
#         self.assertRaises(TypeError)
#  a = ast.literal_eval(json.dumps(schema_types))
#         print(a)
#         print(data)
#         for idx, item in enumerate(data):
#             try:
#                 validate(item, a)
#             except jsonschema.exceptions.ValidationError as ve:
#                 sys.stderr.write("Record #{}: ERROR\n".format(idx))
#                 sys.stderr.write(str(ve) + "\n")
