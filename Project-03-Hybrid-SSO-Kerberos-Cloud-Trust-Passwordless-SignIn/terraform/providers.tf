terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.11.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatewojtech2026"
    container_name       = "tfstate"
    key                  = "win-11-host.tfstate"
    use_azuread_auth     = true
    use_oidc             = true

  }
}

provider "azurerm" {
  features {}
  use_oidc             = true

}

