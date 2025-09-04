resource "azurerm_subnet" "subnet"{
  for_each             = var.subnets
  
  name                 = "subnet_${var.client_code}_${each.key}"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value]
}