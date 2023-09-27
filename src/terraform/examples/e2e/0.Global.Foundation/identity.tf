#####################################################################################################################
# Managed Identity (https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview) #
#####################################################################################################################

resource "azurerm_user_assigned_identity" "studio" {
  name                = module.global.managedIdentity.name
  resource_group_name = azurerm_resource_group.studio.name
  location            = azurerm_resource_group.studio.location
}
