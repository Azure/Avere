# OpenCue Render Manager

<a href="http://www.opencue.io">OpenCue</a> is an open source render manager for visual effects and animation content creation. This section contains an Azure Resource Manager (ARM) template for deploying OpenCue in Azure. The deployment template (<a href="http://github.com/Azure/Avere/blob/master/src/tutorials/opencue/azuredeploy.json">azuredeploy.json</a>) includes the following OpenCue solution architecture components:

* **PostgreSQL Database** - https://www.opencue.io/docs/getting-started/setting-up-the-database/

* **Java App Service** - https://www.opencue.io/docs/getting-started/deploying-cuebot/

* **Render Node** - https://www.opencue.io/docs/getting-started/deploying-rqd/

For an introduction and overview of OpenCue, refer to https://www.opencue.io/docs/concepts/opencue-overview/

### Render Node

In addition to hosting the RQD agent for communication with the Cuebot app service, the render node image also has autofs setup to an NFS endpoint, which is specified as an input parameter before OpenCue deployment. This enables access to the data cache service for client applications (such as Blender) that are running on each render node.
