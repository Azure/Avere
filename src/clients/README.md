# Virtual Machine Client Implementations that mount Avere vFXT

This folder includes two Virtual Machine implementations to deploy multiple VMs mounted to the Avere vFXT: Virtual Machine Availability Sets (VMAS), and Virtual Machine Scale Sets (VMSS).

In both examples, the clients are mounted roundrobin across the Avere vFXT vServer IP addresses.  A bootstrap script stored on the vFXT does this round robin mounting, and provides a mechanism to deploy software on the machine.

# Virtual Machine Availability Sets (VMAS)

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclients%2Fvmas%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

# Virtual Machine Scale Sets (VMSS)

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclients%2Fvmss%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>