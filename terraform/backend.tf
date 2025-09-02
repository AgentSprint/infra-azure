terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "rg-statefile"
    storage_account_name = "agentsprinttfstate12345"
    container_name       = "tfstate"
    key                  = "infra/terraform.tfstate"
    use_azuread_auth     = true
  }
}