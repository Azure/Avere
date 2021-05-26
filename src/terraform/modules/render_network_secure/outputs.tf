output "vnet_resource_group" {
  description = "The resource group of the virtual network."
  value       = azurerm_resource_group.render_rg.name
}

output "vnet_name" {
  description = "The name of the virtual network."
  value       = azurerm_virtual_network.vnet.name
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

output "proxy_subnet_name" {
  description = "The name of the proxy subnet."
  value       = azurerm_subnet.proxy.name
}

output "proxy_subnet_id" {
  description = "The full id of the proxy subnet."
  value       = azurerm_subnet.proxy.id
}
