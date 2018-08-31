# NFS NAS Core Filer

The templates in this folder implements an NFS based NAS Filer described in [Why use the Avere vFXT for Rendering?](../../../docs/why_avere_for_rendering.md).

A VNET is created for the NAS filer, but you can easily adjust the templates to replace the VNET resource with reference to your own VNET.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fnfslatency%azuredisknfs%2Fnfs-azuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

Use python 2.7 with this project.  The script `gen-arm-templates.py` takes as inputs `installdataingestor.sh`, and `base-template*.json`, and outputs to `dataingestor-azuredeploy.*.json`.