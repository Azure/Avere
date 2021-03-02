output "module_depends_on_id" {
  description = "the id(s) to force others to wait"

  value = azurerm_virtual_machine_extension.cse
}
