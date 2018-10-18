# VNET Peering of NFS NAS Core Filers

The template and parameter files implement the VNET peering described in [Why use the Avere vFXT for Rendering?](../../../docs/why_avere_for_rendering.md).

The main East US VNETs is peered to 4 smaller VNETs, as shown in the following diagram:

<img src="../../../docs/images/nfs_latency/vnet_peering.png">

For each VNET peering, you need to apply the template twice: once from source to target, and once from target to source.  To implement the above diagram use the parameter files in this folder as a guide, and click the "Deploy to Azure" button 8 times (or use cloud shell to script deploy):

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Ftutorials%2Fnfslatency%2Fvnetpeering%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

