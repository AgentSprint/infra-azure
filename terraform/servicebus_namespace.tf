resource "azurerm_servicebus_namespace" "servicebus" {
  name                          = "servicebus-${var.client_code}-namespace"
  location                      = azurerm_resource_group.core.location
  resource_group_name           = azurerm_resource_group.core.name
  sku                           = "Premium"
  capacity                      = 1
  premium_messaging_partitions  = 1   # <-- required by provider for Premium
  public_network_access_enabled = false
}
