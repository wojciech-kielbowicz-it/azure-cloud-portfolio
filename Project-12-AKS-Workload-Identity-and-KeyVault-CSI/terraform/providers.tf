terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.11.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatewojtech2026"
    container_name       = "tfstate"
    key                  = "aks-workload-identity-kv-csi.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  use_oidc = true
}

provider "kubectl" {
  host                   = data.azurerm_kubernetes_cluster.aks_compute.kube_config[0].host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks_compute.kube_config[0].cluster_ca_certificate)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login",
      "azurecli",
      "--server-id",
      "6dae42f8-4368-4678-94ff-3960e28e3630"
    ]
  }
}
