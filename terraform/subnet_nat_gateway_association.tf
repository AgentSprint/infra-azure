resource "azurerm_subnet_nat_gateway_association" "subnet_nat_assoc" {
  subnet_id      = azurerm_subnet.subnet["agent"].id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}