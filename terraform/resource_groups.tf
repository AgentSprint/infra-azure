resource "azurerm_resource_group"{
    name        = "rg-${var.client_code}-core"
    location    =  var.location
}

resource "azurerm_resource_group" {
    name        = "rg-${var.client_code}-jump"
    location    = var.location
}

resource "azurerm_resource_group" {
    name        = "rg-${var.client_code}-agent"
    location    = var.location
}
