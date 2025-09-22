resource "azurerm_private_endpoint" "pe" {
  name                = "pe-sb-${var.client_code}"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  subnet_id           = azurerm_subnet.subnet["privatelink"].id

  private_service_connection {
    name                           = "pe-servicebus"
    private_connection_resource_id = azurerm_servicebus_namespace.servicebus.id
    is_manual_connection           = false # Set to true for manual approval
    subresource_names              = ["namespace"]
  }
  private_dns_zone_group {
    name                 = "pe-sb-private-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns.id]
  }
}