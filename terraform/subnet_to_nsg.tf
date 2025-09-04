resource "azurerm_subnet_network_security_group_association" "core_assoc" {
  for_each            = toset(var.base_groups)

  subnet_id                 = azurerm_subnet.subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}
