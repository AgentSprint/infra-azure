resource "azurerm_user_assigned_identity" "uai_servicebus" {
  location            = azurerm_resource_group.core.location
  name                = "uai-${var.client_code}-servicebus"
  resource_group_name = azurerm_resource_group.core.name
}