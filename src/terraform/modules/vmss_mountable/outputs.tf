// send back the ip addresses of the VMSS nodes
output "vmss_id" {
  description = "The arm id of the VMSS."
  value       = azurerm_virtual_machine_scale_set.vmss.id
}

// send back the ip addresses of the VMSS nodes
output "vmss_resource_group" {
  description = "The resource group of the VMSS."
  value       = azurerm_virtual_machine_scale_set.vmss.resource_group_name
}

output "vmss_name" {
    description = "The name of the resource group."
    value = azurerm_virtual_machine_scale_set.vmss.name
}
