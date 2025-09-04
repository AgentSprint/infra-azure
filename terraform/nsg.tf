resource "azurerm_network_security_group" "nsg" {
  for_each            = toset(var.base_groups)

  name                = "nsg-${var.client_code}-${each.key}"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
}
