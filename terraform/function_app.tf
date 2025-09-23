resource "azurerm_storage_account" "func_storage_account" {
  name                     = "funcstorage${var.client_code}"
  resource_group_name      = azurerm_resource_group.core.name
  location                 = azurerm_resource_group.core.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_service_plan" "func_service_plan" {
  name                = "azure-functions-${var.client_code}-sp"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  os_type             = "Linux"
  sku_name            = "P1v2"
}


resource "azurerm_linux_function_app" "linux_function_app" {
  name                = "func-${var.client_code}"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name

  storage_account_name       = azurerm_storage_account.func_storage_account.name
  storage_account_access_key = azurerm_storage_account.func_storage_account.primary_access_key
  service_plan_id            = azurerm_service_plan.func_service_plan.id

  # Enable system-assigned identity for secure auth
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uai_servicebus.id]
  }

  site_config {
    application_stack {
      python_version = "3.12" # safer, fully supported (3.12 may not work in all regions yet)
    }
    vnet_route_all_enabled = true
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    AzureWebJobsStorage      = azurerm_storage_account.func_storage_account.primary_connection_string
  }

  lifecycle {
    ignore_changes = [
      app_settings["AzureWebJobsStorage"], # avoid Terraform drift on this
    ]
  }
}


resource "azurerm_app_service_virtual_network_swift_connection" "func_vnet_integration" {
  app_service_id = azurerm_linux_function_app.linux_function_app.id
  subnet_id      = azurerm_subnet.subnet_func.id
}
