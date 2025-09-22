resource "azurerm_private_dns_zone" "private_dns" {
  name                = "private-dns-${var.client_code}.servicebus.windows.net"
  resource_group_name = azurerm_resource_group.core.name
}
