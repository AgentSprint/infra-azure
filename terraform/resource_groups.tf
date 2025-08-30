resource "azurerm_resource_group" "core" {
    name        = "rg-${var.client_code}-core"
    location    =  var.location
}

resource "azurerm_resource_group" "jump" {
    name        = "rg-${var.client_code}-jump"
    location    = var.location
}

resource "azurerm_resource_group" "agent" {
    name        = "rg-${var.client_code}-agent"
    location    = var.location
}
