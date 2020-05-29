output "vnet_resource_group" {
  description = "The resource group of the virtual network."
  value       = azurerm_resource_group.render_rg.name
}

output "vnet_name" {
  description = "The name of the virtual network."
  value       = azurerm_virtual_network.vnet.name
}

output "vnet_id" {
  description = "The id of the virtual network."
  value       = azurerm_virtual_network.vnet.id
}

output "cloud_cache_subnet_name" {
  description = "The name of the cloud cache subnet."
  value       = azurerm_subnet.cloud_cache.name
}

output "cloud_cache_subnet_id" {
  description = "The full id of the cloud cache subnet."
  value       = azurerm_subnet.cloud_cache.id
}

output "cloud_filers_subnet_name" {
  description = "The name of the cloud filers subnet."
  value       = azurerm_subnet.cloud_filers.name
}

output "cloud_filers_subnet_id" {
  description = "The full id of the cloud filers subnet."
  value       = azurerm_subnet.cloud_filers.id
}

output "jumpbox_subnet_name" {
  description = "The name of the jumpbox subnet."
  value       = azurerm_subnet.jumpbox.name
}

output "jumpbox_subnet_id" {
  description = "The full id of the jumpbox subnet."
  value       = azurerm_subnet.jumpbox.id
}

output "render_clients1_subnet_name" {
  description = "The name of the render clients 1 subnet."
  value       = azurerm_subnet.render_clients1.name
}

output "render_clients1_subnet_id" {
  description = "The full id of the render clients 1 subnet."
  value       = azurerm_subnet.render_clients1.id
}

output "render_clients2_subnet_name" {
  description = "The name of the render clients 2 subnet."
  value       = azurerm_subnet.render_clients2.name
}

output "render_clients2_subnet_id" {
  description = "The full id of the render clients 2 subnet."
  value       = azurerm_subnet.render_clients2.id
}

output "module_depends_on_ids" {
  description = "the id(s) to force others to wait"
  value = [azurerm_subnet_network_security_group_association.cloud_cache.id,azurerm_subnet_network_security_group_association.cloud_filers.id,azurerm_subnet_network_security_group_association.jumpbox.id,azurerm_subnet_network_security_group_association.render_clients1.id,azurerm_subnet_network_security_group_association.render_clients2.id]
}