output "vnet_name" {
  description = "The name of the virtual network."
  value       = azurerm_virtual_network.vnet.name
}

output "cloud_cache_subnet_name" {
  description = "The name of the cloud cache subnet."
  value       = var.subnet_cloud_cache_subnet_name
}

output "cloud_filers_subnet_name" {
  description = "The name of the cloud filers subnet."
  value       = var.subnet_cloud_filers_subnet_name
}

output "render_clients1_subnet_name" {
  description = "The name of the render clients 1 subnet."
  value       = var.subnet_render_clients1_subnet_name
}

output "render_clients2_subnet_name" {
  description = "The name of the render clients 2 subnet."
  value       = var.subnet_render_clients2_subnet_name
}