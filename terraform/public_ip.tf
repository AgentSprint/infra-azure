resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.client_code}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  allocation_method   = "Static"
}