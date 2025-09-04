resource "azurerm_nat_gateway_public_ip_association" "nat_pip__assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.pip.id
}