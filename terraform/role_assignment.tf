resource "azurerm_role_assignment" "role_assignment" {
      scope                = azurerm_servicebus_namespace.servicebus.id
      role_definition_name = "Azure Service Bus Data Sender"
      principal_id         = azurerm_user_assigned_identity.uai_servicebus.principal_id
    }