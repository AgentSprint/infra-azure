
resource "azurerm_private_dns_zone_virtual_network_link" "vnet-dns" {
  name                  = "link-vnet-${var.client_code}-dns"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}