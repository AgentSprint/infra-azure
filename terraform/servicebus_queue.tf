resource "azurerm_servicebus_queue" "sb_queue" {
  name         = "q_work"
  namespace_id = azurerm_servicebus_namespace.servicebus.id
}