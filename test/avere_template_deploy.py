#!/usr/bin/python3

"""
Class used for testing template-based deployment of the Avere vFXT product.

Objects require the following environment variables at instantiation:
    * AVERE_ADMIN_PW
    * AVERE_CONTROLLER_PW
    * AZURE_CLIENT_ID
    * AZURE_CLIENT_SECRET
    * AZURE_TENANT_ID
    * AZURE_SUBSCRIPTION_ID
"""

import json
import os
from datetime import datetime
from pprint import pformat
from random import choice
from string import ascii_lowercase

from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode, TemplateLink


class AvereTemplateDeploy:
    def __init__(self, deploy_params={}, resource_group=None,
                 location='eastus2', debug=False):
        """Initialize, authenticate to Azure, generate deploy params."""
        self.template_link = TemplateLink(
            uri='https://raw.githubusercontent.com/' +
                'Azure/Avere/master/src/vfxt/azuredeploy-auto.json')
        self.debug = debug

        self.deploy_params = deploy_params
        self.resource_group = self.deploy_params.pop('resourceGroup',
                                                     resource_group)
        self.location = self.deploy_params.pop('location', location)
        self.ssh_pub_key_path = os.path.expanduser('~/.ssh/id_rsa.pub')

        self._debug('> Loading Azure credentials')
        self.rm_client = ResourceManagementClient(
            credentials=ServicePrincipalCredentials(
                client_id=os.environ['AZURE_CLIENT_ID'],
                secret=os.environ['AZURE_CLIENT_SECRET'],
                tenant=os.environ['AZURE_TENANT_ID']
            ),
            subscription_id=os.environ['AZURE_SUBSCRIPTION_ID']
        )

        if not self.deploy_params:
            gen_id = 'av' + \
                datetime.utcnow().strftime('%m%d%H%M%S') + \
                choice(ascii_lowercase)
            self.resource_group = gen_id + '-rg'
            self.deploy_params = {
                'virtualNetworkResourceGroup': self.resource_group,
                'virtualNetworkName': gen_id + '-vnet',
                'virtualNetworkSubnetName': gen_id + '-subnet',
                'avereBackedStorageAccountName': gen_id + 'sa',
                'controllerName': gen_id + '-con',
                'controllerAuthenticationType': 'sshPublicKey'
            }
            self._debug('> Generated deploy parameters: \n{}'.format(
                json.dumps(self.deploy_params, indent=4)))

    def create_resource_group(self):
        """Creates the Azure resource group for this deployment."""
        self._debug('> Creating resource group: ' + self.resource_group)
        return self.rm_client.resource_groups.create_or_update(
            self.resource_group,
            {'location': self.location}
        )

    def delete_resource_group(self):
        """Deletes the Azure resource group for this deployment."""
        self._debug('> Deleting resource group: ' + self.resource_group)
        return self.rm_client.resource_groups.delete(self.resource_group)

    def deploy(self, add_secrets_params=True):
        """Deploys the Avere vFXT template."""
        self._debug('> Deploying template')

        params = {**self.deploy_params}
        if add_secrets_params:
            with open(self.ssh_pub_key_path, 'r') as ssh_pub_key_file:
                ssh_pub_key = ssh_pub_key_file.read()

            deploy_secrets = {
                'adminPassword': os.environ['AVERE_ADMIN_PW'],
                'controllerPassword': os.environ['AVERE_CONTROLLER_PW'],
                'servicePrincipalAppId': os.environ['AZURE_CLIENT_ID'],
                'servicePrincipalPassword': os.environ['AZURE_CLIENT_SECRET'],
                'servicePrincipalTenant': os.environ['AZURE_TENANT_ID'],
                'controllerSSHKeyData': ssh_pub_key
            }
            params = {**deploy_secrets, **params}

        return self.rm_client.deployments.create_or_update(
            resource_group_name=self.resource_group,
            deployment_name='avere_template_deploy',
            properties={
                'mode': DeploymentMode.incremental,
                'parameters': {k: {'value': v} for k, v in params.items()},
                'template_link': self.template_link
            }
        )

    def _debug(self, s):
        """Prints the passed string, with a DEBUG header, if debug is on."""
        if self.debug:
            print('[DEBUG]: {}'.format(s))

    def __str__(self):
        return pformat(vars(self), indent=4)


if __name__ == '__main__':
    pass
