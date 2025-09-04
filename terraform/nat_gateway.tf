resource "azurerm_nat_gateway" "nat" {
  name                    = "nat-${var.client_code}"
  location                = azurerm_resource_group.core.location
  resource_group_name     = azurerm_resource_group.core.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}