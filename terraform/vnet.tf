resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.client_code}"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  address_space       = [var.vnet_ip_address_space]
}