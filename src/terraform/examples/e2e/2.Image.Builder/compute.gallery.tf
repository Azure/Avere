###############################################################################################
# Compute Gallery (https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) #
###############################################################################################

variable "computeGallery" {
  type = object(
    {
      name = string
      imageDefinitions = list(object(
        {
          name       = string
          type       = string
          generation = string
          publisher  = string
          offer      = string
          sku        = string
        }
      ))
    }
  )
}

resource "azurerm_shared_image_gallery" "gallery" {
  name                = var.computeGallery.name
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
}

resource "azurerm_shared_image" "definitions" {
  count               = length(var.computeGallery.imageDefinitions)
  name                = var.computeGallery.imageDefinitions[count.index].name
  resource_group_name = azurerm_resource_group.image.name
  location            = azurerm_resource_group.image.location
  gallery_name        = azurerm_shared_image_gallery.gallery.name
  os_type             = var.computeGallery.imageDefinitions[count.index].type
  hyper_v_generation  = var.computeGallery.imageDefinitions[count.index].generation
  identifier {
    publisher = var.computeGallery.imageDefinitions[count.index].publisher
    offer     = var.computeGallery.imageDefinitions[count.index].offer
    sku       = var.computeGallery.imageDefinitions[count.index].sku
  }
}

output "imageDefinitionLinux" {
  value = one([
    for imageDefinition in var.computeGallery.imageDefinitions: imageDefinition if imageDefinition.type == "Linux"
  ])
}
