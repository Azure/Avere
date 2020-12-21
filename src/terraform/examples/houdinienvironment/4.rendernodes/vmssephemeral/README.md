# Windows VMSS with Ephemeral OS Disks

This example must be run with the environment variable [ARM_PROVIDER_VMSS_EXTENSIONS_BETA](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set#extension) must be set to `true`.

On Windows you set the following before running terraform apply:

```powershell
set ARM_PROVIDER_VMSS_EXTENSIONS_BETA=true
```

The `main.tf` implements the [VMSS best practices](../../../vmss-rendering).