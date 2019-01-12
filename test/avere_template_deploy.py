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

import logging
import os
from datetime import datetime
from pprint import pformat
from random import choice
from string import ascii_lowercase

from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode


class AvereTemplateDeploy:
    def __init__(self, deploy_params={}, resource_group=None,
                 location='eastus2', deploy_name='azurePySDK', template={},
                 deploy_id=None):
        """Initialize, authenticate to Azure."""
        self.deploy_params = deploy_params
        self.resource_group = self.deploy_params.pop('resourceGroup',
                                                     resource_group)
        self.location = self.deploy_params.pop('location', location)
        self.deploy_name = self.deploy_params.pop('deployName', deploy_name)
        self.template = self.deploy_params.pop('template', template)
        self.deploy_id = self.deploy_params.pop('deployId', deploy_id)

        if not self.deploy_id:
            self.deploy_id = 'av' + \
                datetime.utcnow().strftime('%m%dx%H%M%S') + \
                choice(ascii_lowercase)

        if not self.resource_group:
            self.resource_group = self.deploy_id + '-rg'

        logging.debug('> Loading Azure credentials')
        sp_creds = ServicePrincipalCredentials(
            client_id=os.environ['AZURE_CLIENT_ID'],
            secret=os.environ['AZURE_CLIENT_SECRET'],
            tenant=os.environ['AZURE_TENANT_ID']
        )
        self.rm_client = ResourceManagementClient(
            credentials=sp_creds,
            subscription_id=os.environ['AZURE_SUBSCRIPTION_ID']
        )
        self.nm_client = NetworkManagementClient(
            credentials=sp_creds,
            subscription_id=os.environ['AZURE_SUBSCRIPTION_ID']
        )

    def create_resource_group(self):
        """Creates the Azure resource group for this deployment."""
        logging.debug('> Creating resource group: ' + self.resource_group)
        return self.rm_client.resource_groups.create_or_update(
            self.resource_group,
            {'location': self.location}
        )

    def delete_resource_group(self):
        """Deletes the Azure resource group for this deployment."""
        logging.debug('> Deleting resource group: ' + self.resource_group)
        return self.rm_client.resource_groups.delete(self.resource_group)

    def deploy(self):
        """Deploys the Avere vFXT template."""
        logging.debug('> Deploying template')
        return self.rm_client.deployments.create_or_update(
            resource_group_name=self.resource_group,
            deployment_name=self.deploy_name,
            properties={
                'mode': DeploymentMode.incremental,
                'parameters':
                    {k: {'value': v} for k, v in self.deploy_params.items()},
                'template': self.template
            }
        )

    def __str__(self):
        return pformat(vars(self), indent=4)


if __name__ == '__main__':
    pass
