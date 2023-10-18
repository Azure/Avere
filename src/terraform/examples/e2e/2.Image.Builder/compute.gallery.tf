###############################################################################################
# Compute Gallery (https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) #
###############################################################################################

variable "computeGallery" {
  type = object({
    name = string
    imageDefinition = map(object({
      type       = string
      generation = string
      publisher  = string
      offer      = string
      sku        = string
    }))
    replicationRegions = list(string)
  })
}

resource "azurerm_shared_image_gallery" "studio" {
  name                = var.computeGallery.name
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
}

resource "azurerm_shared_image" "studio" {
  for_each            = var.computeGallery.imageDefinition
  name                = each.key
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
  gallery_name        = azurerm_shared_image_gallery.studio.name
  os_type             = each.value.type
  hyper_v_generation  = each.value.generation
  identifier {
    publisher = each.value.publisher
    offer     = each.value.offer
    sku       = each.value.sku
  }
}

output "imageDefinition" {
  value = var.computeGallery.imageDefinition
}
